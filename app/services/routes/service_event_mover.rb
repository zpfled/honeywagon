module Routes
  class ServiceEventMover
    def initialize(service_event)
      @service_event = service_event
      @route = resolve_route
      @company = service_event.order&.company || @route&.company
    end

    def move_to_next
      return locked_failure('Completed events cannot be moved.') if service_event.status_completed?
      return locked_failure('Deliveries must stay on or before their scheduled date.') if service_event.prevent_move_later?

      target_route = next_candidate
      return failure('Unable to postpone service event.') unless target_route

      move_to_route(target_route, 'Service event postponed to the next route.')
    end

    def move_to_previous
      return locked_failure('Completed events cannot be moved.') if service_event.status_completed?
      return locked_failure('Pickups must stay on or before their scheduled date.') if service_event.prevent_move_earlier?

      target_route = previous_candidate
      return failure('No earlier route available for this service event.') unless target_route

      move_to_route(target_route, 'Service event moved to the previous route.')
    end

    private

    attr_reader :service_event, :route, :company

    def resolve_route
      service_event.route ||
        RouteStop.includes(:route).where(service_event_id: service_event.id).order(:position).first&.route
    end

    def move_to_route(target_route, success_message)
      source_route = route
      source_stop = source_route&.route_stops&.find_by(service_event_id: service_event.id)
      existing_stop = RouteStop.find_by(service_event_id: service_event.id)

      new_position = target_route.route_stops.maximum(:position).to_i + 1

      ActiveRecord::Base.transaction do
        source_stop&.destroy!
        source_route&.synchronize_route_sequence_with_stops!

        if existing_stop && existing_stop != source_stop
          existing_stop.update!(route: target_route, position: new_position, status: service_event.status)
        else
          target_route.route_stops.create!(
            service_event: service_event,
            position: new_position,
            status: service_event.status
          )
        end
        # Reload to clear association cache so logistics validation reads the
        # newly assigned route stop (important for pickup/delivery constraints).
        service_event.reload
        service_event.update!(scheduled_on: target_route.route_date)
        target_route.synchronize_route_sequence_with_stops!
      end

      service_event.reload

      Rails.logger.info(
        "[ServiceEventMover] moved event=#{service_event.id} to route=#{target_route.id}, route_date=#{target_route.route_date}"
      )
      Routes::ServiceEventActionResult.new(route: target_route, success: true, message: success_message)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.warn(
        "[ServiceEventMover] failed to move event=#{service_event.id} to route=#{target_route.id}: #{e.message}"
      )
      failure(e.message)
    rescue StandardError => e
      Rails.logger.warn(
        "[ServiceEventMover] failed to move event=#{service_event.id} to route=#{target_route.id}: #{e.message}"
      )
      failure('Unable to update service event.')
    end

    def next_candidate
      return unless route && company

      company.routes.where('route_date > ?', route.route_date)
             .order(:route_date)
             .first || create_next_route
    end

    def previous_candidate
      return unless route && company

      company.routes
             .where('route_date < ?', route.route_date)
             .order(route_date: :desc)
             .first || create_previous_route
    end

    def create_next_route
      company.routes.create!(
        route_date: route.route_date + 1.day,
        truck: route.truck,
        trailer: route.trailer
      )
    end

    def create_previous_route
      company.routes.create!(
        route_date: route.route_date - 1.day,
        truck: route.truck,
        trailer: route.trailer
      )
    end

    def failure(message)
      Routes::ServiceEventActionResult.new(route: route, success: false, message: message)
    end

    def locked_failure(message)
      failure(message)
    end
  end
end
