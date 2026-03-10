module Routes
  class ServiceEventUncompleter
    def initialize(service_event)
      @service_event = service_event
    end

    def call
      return failure('Only completed service events can be uncompleted.') unless service_event.status_completed?
      return failure('This service event cannot be uncompleted because it has a completed service log with gallons recorded.') unless service_event.uncompletion_allowed?

      if service_event.update(status: :scheduled, completed_on: nil)
        Routes::ServiceEventActionResult.new(route: resolved_route, success: true, message: 'Service event marked not completed.')
      else
        failure(service_event.errors.full_messages.to_sentence.presence || 'Unable to uncomplete service event.')
      end
    end

    private

    attr_reader :service_event

    def failure(message)
      Routes::ServiceEventActionResult.new(route: resolved_route, success: false, message: message)
    end

    def resolved_route
      service_event.route || RouteStop.includes(:route).where(service_event_id: service_event.id).order(:position).first&.route
    end
  end
end
