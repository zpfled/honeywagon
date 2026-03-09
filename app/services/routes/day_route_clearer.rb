module Routes
  class DayRouteClearer
    Result = Struct.new(:success?, :routes_cleared, :events_released, :error, keyword_init: true)

    def initialize(run:, date:)
      @run = run
      @date = date
    end

    def call
      return failure("Only future dates can be cleared.") if date < Date.current

      routes = run.routes.where(route_date: date).includes(:service_events, route_stops: :service_event).to_a
      return Result.new(success?: true, routes_cleared: 0, events_released: 0, error: nil) if routes.empty?

      events_to_release = routes.flat_map do |route|
        (route.route_stops.map(&:service_event) + route.service_events.to_a).compact
      end.uniq

      ActiveRecord::Base.transaction do
        events_to_release.each do |event|
          event.update!(
            route: nil,
            route_date: event.scheduled_on,
            route_sequence: nil
          )
        end

        routes.each do |route|
          route.route_stops.delete_all
          route.destroy!
        end
      end

      Result.new(
        success?: true,
        routes_cleared: routes.size,
        events_released: events_to_release.size,
        error: nil
      )
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      failure(e.message)
    end

    private

    attr_reader :run, :date

    def failure(message)
      Result.new(success?: false, routes_cleared: 0, events_released: 0, error: message)
    end
  end
end
