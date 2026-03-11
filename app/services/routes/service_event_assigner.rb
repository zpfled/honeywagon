module Routes
  class ServiceEventAssigner
    MAX_ASSIGNMENT_WINDOW_DAYS = 14

    def initialize(service_event:, route:, actor: nil)
      @service_event = service_event
      @route = route
      @actor = actor
    end

    def call
      return failure('Only scheduled service events can be assigned to a route.') unless service_event.status_scheduled?
      return failure('Service event is missing a scheduled date.') if service_event.scheduled_on.blank?
      return failure('Service event is already assigned to a different route.') if assigned_to_different_route?
      return failure('Pick a route within 2 weeks of the service date.') if outside_assignment_window?

      ActiveRecord::Base.transaction do
        route.append_service_event_stop!(service_event, created_by: actor)
        service_event.reload
        service_event.update!(scheduled_on: route.route_date)
        route.synchronize_route_sequence_with_stops!
      end

      Routes::ServiceEventActionResult.new(route: route, success: true, message: 'Service event assigned to route.')
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence.presence || 'Unable to assign route.')
    end

    private

    attr_reader :service_event, :route, :actor

    def assigned_to_different_route?
      service_event.route.present? && service_event.route != route
    end

    def outside_assignment_window?
      event_date = service_event.scheduled_on.to_date
      route_date = route.route_date.to_date

      (route_date - event_date).abs > MAX_ASSIGNMENT_WINDOW_DAYS
    end

    def failure(message)
      Routes::ServiceEventActionResult.new(route: route, success: false, message: message)
    end
  end
end
