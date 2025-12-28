module Routes
  class ShowSummaryPresenter
    def initialize(route:, waste_load: nil)
      @route = route
      @waste_load = waste_load
    end

    def trailer_usage = capacity_summary.trailer_usage
    def clean_usage = capacity_summary.clean_water_usage
    def waste_usage = capacity_summary.waste_usage

    def waste_summary
      @waste_summary ||= begin
        summary = {
          cumulative_used: waste_usage[:used],
          capacity: waste_usage[:capacity],
          remaining: waste_usage[:capacity] ? waste_usage[:capacity] - waste_usage[:used] : nil,
          over_capacity: waste_usage[:capacity] && waste_usage[:used] > waste_usage[:capacity]
        }
        waste_load || summary
      end
    end

    def drive_time = route_presenter.humanized_drive_time
    def drive_distance = route_presenter.humanized_drive_distance

    def drive_present?
      drive_time.present? || drive_distance.present?
    end

    def optimization_stale?
      route.optimization_stale? && drive_present?
    end

    def truck_label
      route.truck&.label || 'Unassigned'
    end

    def trailer_label
      route.trailer&.label || 'None'
    end

    private

    attr_reader :route, :waste_load

    def capacity_summary
      @capacity_summary ||= route.capacity_summary
    end

    def route_presenter
      @route_presenter ||= RoutePresenter.new(route)
    end
  end
end
