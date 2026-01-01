module Routes
  class ShowSummaryPresenter
    # Presents the high-level summary (capacity, waste, drive metrics, labels) for the route show page.
    # Keeps the view free of aggregation/formatting logic and centralizes summary calculations.
    def initialize(route:, waste_load: nil)
      @route = route
      @waste_load = waste_load
    end

    # Capacity usage by resource.
    def trailer_usage = capacity_summary.trailer_usage
    def clean_usage = capacity_summary.clean_water_usage
    def waste_usage = capacity_summary.waste_usage

    # Waste summary prefers a precomputed load (e.g., cumulative truck waste), otherwise falls back to per-route capacity usage.
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

    # Estimated drive metrics from RoutePresenter (already formatted for display).
    def drive_time = route_presenter.humanized_drive_time
    def drive_distance = route_presenter.humanized_drive_distance

    def drive_present?
      drive_time.present? || drive_distance.present?
    end

    # Only show stale warning when we have metrics to display.
    def optimization_stale?
      route.optimization_stale? && drive_present?
    end

    # Labels for truck/trailer summary.
    def truck_label
      route.truck&.label || 'Unassigned'
    end

    def trailer_label
      route.trailer&.label || 'None'
    end

    def trailer_usage_label
      usage = trailer_usage
      "#{usage[:used]} / #{usage[:capacity] || '—'}"
    end

    def trailer_usage_class
      usage = trailer_usage
      usage[:capacity] && usage[:used] > usage[:capacity] ? 'text-rose-700' : ''
    end

    def clean_usage_label
      usage = clean_usage
      "#{usage[:used]} / #{usage[:capacity] || '—'} gal"
    end

    def clean_usage_class
      usage = clean_usage
      usage[:capacity] && usage[:used] > usage[:capacity] ? 'text-rose-700' : ''
    end

    def waste_usage_label
      summary = waste_summary
      "#{summary[:cumulative_used]} / #{summary[:capacity] || '—'} gal"
    end

    def waste_usage_class
      waste_summary[:over_capacity] ? 'text-rose-700' : ''
    end

    def drive_label
      [drive_time, drive_distance].compact.join(' • ').presence
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
