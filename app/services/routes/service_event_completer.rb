module Routes
  class ServiceEventCompleter
    def initialize(service_event)
      @service_event = service_event
    end

    def call
      if service_event.update(status: :completed)
        reschedule_future_events if service_event.event_type_service?
        Routes::ServiceEventActionResult.new(route: service_event.route, success: true, message: 'Service event marked completed.')
      else
        Routes::ServiceEventActionResult.new(route: service_event.route, success: false, message: service_event.errors.full_messages.to_sentence.presence || 'Unable to complete service event.')
      end
    end

    private

    attr_reader :service_event

    def reschedule_future_events
      Orders::ServiceEventRescheduler.new(service_event.order).shift_from(completion_date: Date.current)
    end
  end
end
