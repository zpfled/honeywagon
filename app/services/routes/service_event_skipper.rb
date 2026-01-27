module Routes
  class ServiceEventSkipper
    def initialize(service_event, skip_reason:)
      @service_event = service_event
      @skip_reason = skip_reason.to_s.strip
    end

    def call
      return failure('Only scheduled service events can be skipped.') unless service_event.status_scheduled?
      return failure('Only service events can be skipped.') unless service_event.event_type_service?
      return failure('Skip reason is required.') if skip_reason.blank?

      if service_event.update(status: :skipped, skip_reason: skip_reason, skipped_on: Date.current)
        reschedule_future_events
        Routes::ServiceEventActionResult.new(route: service_event.route, success: true, message: 'Service event marked skipped.')
      else
        failure(service_event.errors.full_messages.to_sentence.presence || 'Unable to skip service event.')
      end
    end

    private

    attr_reader :service_event, :skip_reason

    def reschedule_future_events
      return unless service_event.order

      Orders::ServiceEventRescheduler.new(service_event.order).shift_from(completion_date: service_event.skipped_on || Date.current)
    end

    def failure(message)
      Routes::ServiceEventActionResult.new(route: service_event.route, success: false, message: message)
    end
  end
end
