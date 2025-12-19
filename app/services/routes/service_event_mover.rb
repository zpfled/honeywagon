module Routes
  class ServiceEventMover
    def initialize(service_event)
      @service_event = service_event
      @route = service_event.route
      @company = service_event.order&.company || @route&.company
    end

    def move_to_next
      return locked_failure('Deliveries must stay on or before their scheduled date.') if service_event.prevent_move_later?

      route = next_candidate
      return failure('Unable to postpone service event.') unless route

      update_event(route, 'Service event postponed to the next route.')
    end

    def move_to_previous
      return locked_failure('Pickups must stay on their scheduled date.') if service_event.prevent_move_earlier?

      route = previous_candidate
      return failure('No earlier route available for this service event.') unless route

      update_event(route, 'Service event moved to the previous route.')
    end

    private

    attr_reader :service_event, :route, :company

    def update_event(target_route, success_message)
      attrs = {
        route: target_route,
        route_date: target_route.route_date,
        scheduled_on: target_route.route_date
      }

      if service_event.update(attrs)
        Routes::ServiceEventActionResult.new(route: target_route, success: true, message: success_message)
      else
        failure(service_event.errors.full_messages.to_sentence.presence || 'Unable to update service event.')
      end
    end

    def failure(message)
      Routes::ServiceEventActionResult.new(route: route, success: false, message: message)
    end

    def locked_failure(message)
      failure(message)
    end

    def next_candidate
      return unless company && route

      company.routes.where('route_date > ?', route.route_date).order(:route_date).first ||
        company.routes.create(route_date: route.route_date + 1.day)
    end

    def previous_candidate
      return unless company && route

      company.routes
             .where('route_date < ?', route.route_date)
             .order(route_date: :desc)
             .first
    end

    # TODO: migrate to per-company time zones; Central Time is a temporary assumption.
    def central_today
      Time.use_zone('Central Time (US & Canada)') { Time.zone.today }
    end
  end
end
