module Routes
  class ServiceEventMover
    def initialize(service_event)
      @service_event = service_event
      @route = service_event.route
      @company = service_event.order&.company || @route&.company
    end

    def move_to_next
      return locked_failure('Deliveries must stay on or before their scheduled date.') if service_event.prevent_move_later?

      target_route = next_candidate
      return failure('Unable to postpone service event.') unless target_route

      move_to_route(target_route, 'Service event postponed to the next route.')
    end

    def move_to_previous
      return locked_failure('Pickups must stay on or before their scheduled date.') if service_event.prevent_move_earlier?

      target_route = previous_candidate
      return failure('No earlier route available for this service event.') unless target_route

      move_to_route(target_route, 'Service event moved to the previous route.')
    end

    private

    attr_reader :service_event, :route, :company

    def move_to_route(target_route, success_message)
      source_route = route
      source_stop = source_route&.route_stops&.find_by(service_event_id: service_event.id) if source_route&.has_stop_projection?

      service_event.assign_attributes(
        route: target_route,
        route_date: target_route.route_date,
        scheduled_on: target_route.route_date
      )

      ActiveRecord::Base.transaction do
        service_event.save!

        source_stop.destroy! if source_stop
        source_route&.synchronize_route_sequence_with_stops! if source_route&.has_stop_projection?

        if target_route.has_stop_projection?
          target_route.append_service_event_stop!(service_event, created_by: nil)
          target_route.synchronize_route_sequence_with_stops!
        else
          next_sequence = target_route.service_events.maximum(:route_sequence).to_i + 1
          service_event.update_column(:route_sequence, next_sequence)
        end

        if target_route.generation_run.blank? && source_route&.generation_run.present?
          target_route.update_column(:generation_run_id, source_route.generation_run_id)
        end
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

      if route.generation_run.present?
        candidate = company.routes
                           .where(generation_run: route.generation_run)
                           .where('route_date > ?', route.route_date)
                           .order(route_date: :asc)
                           .first
        return candidate if candidate
      end

      company.routes.where('route_date > ?', route.route_date)
             .order(:route_date)
             .first || create_next_route
    end

    def previous_candidate
      return unless route && company

      if route.generation_run.present?
        candidate = company.routes
                           .where(generation_run: route.generation_run)
                           .where('route_date < ?', route.route_date)
                           .order(route_date: :desc)
                           .first
        return candidate if candidate
      end

      company.routes
             .where('route_date < ?', route.route_date)
             .order(route_date: :desc)
             .first || create_previous_route
    end

    def create_next_route
      company.routes.create!(
        route_date: route.route_date + 1.day,
        truck: route.truck,
        trailer: route.trailer,
        generation_run: route&.generation_run
      )
    end

    def create_previous_route
      company.routes.create!(
        route_date: route.route_date - 1.day,
        truck: route.truck,
        trailer: route.trailer,
        generation_run: route&.generation_run
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
