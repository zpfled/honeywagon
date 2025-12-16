module Routes
  class ServiceEventActionResult
    attr_reader :route, :message

    def initialize(route:, success:, message:)
      @route = route
      @success = success
      @message = message
    end

    def success?
      @success
    end
  end
end
