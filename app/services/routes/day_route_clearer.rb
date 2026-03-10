module Routes
  class DayRouteClearer
    Result = Struct.new(:success?, :routes_cleared, :events_released, :error, keyword_init: true)

    def initialize(date:, run: nil, company: nil)
      @run = run
      @company = company
      @date = date
    end

    def call
      return failure('Only future dates can be cleared.') if date < Date.current

      routes = routes_scope.where(route_date: date).includes(route_stops: :service_event).to_a
      return Result.new(success?: true, routes_cleared: 0, events_released: 0, error: nil) if routes.empty?
      return failure('Cannot clear routes for this day because completed events are present.') if completed_events_present?(routes)

      events_to_release = routes.flat_map { |route| route.route_stops.map(&:service_event) }.compact.uniq

      ActiveRecord::Base.transaction do
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

    attr_reader :run, :company, :date

    def routes_scope
      return run.routes if run.present?
      return company.routes if company.present?

      Route.none
    end

    def failure(message)
      Result.new(success?: false, routes_cleared: 0, events_released: 0, error: message)
    end

    def completed_events_present?(routes)
      route_ids = routes.map(&:id)
      RouteStop.joins(:service_event)
               .where(route_id: route_ids)
               .where(service_events: { status: ServiceEvent.statuses[:completed] })
               .exists?
    end
  end
end
