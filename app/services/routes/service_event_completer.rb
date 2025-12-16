module Routes
  class ServiceEventCompleter
    def initialize(service_event)
      @service_event = service_event
    end

    def call
      if service_event.update(status: :completed)
        Routes::ServiceEventActionResult.new(route: service_event.route, success: true, message: 'Service event marked completed.')
      else
        Routes::ServiceEventActionResult.new(route: service_event.route, success: false, message: service_event.errors.full_messages.to_sentence.presence || 'Unable to complete service event.')
      end
    end

    private

    attr_reader :service_event
  end
end
