module Routes
  class ServiceEventCompleter
    def initialize(service_event)
      @service_event = service_event
    end

    def call
      if service_event.update(status: :completed)
        transition_order_after_delivery
        reschedule_future_events if service_event.event_type_service?
        Routes::ServiceEventActionResult.new(route: service_event.route, success: true, message: 'Service event marked completed.')
      else
        Routes::ServiceEventActionResult.new(route: service_event.route, success: false, message: service_event.errors.full_messages.to_sentence.presence || 'Unable to complete service event.')
      end
    end

    private

    attr_reader :service_event

    def reschedule_future_events
      completion_date = service_event.completed_on || Date.current
      Orders::ServiceEventRescheduler.new(service_event.order).shift_from(completion_date: completion_date)
    end

    def transition_order_after_delivery
      return unless service_event.event_type_delivery?

      order = service_event.order
      return unless order&.scheduled?

      order.activate!
    end
  end
end
