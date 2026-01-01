module Routes
  class ShowHeaderPresenter
    def initialize(route:, previous_route:, next_route:, weather_forecast:, view_context:)
      @route = route
      @previous_route = previous_route
      @next_route = next_route
      @weather_forecast = weather_forecast
      @view = view_context
    end

    def route_date_label
      view.l(route.route_date, format: '%A, %B %-d')
    end

    def deliveries_label
      view.pluralize(route_presenter.deliveries_count, 'delivery')
    end

    def services_label
      services = view.pluralize(route_presenter.services_count, 'service')
      units = view.pluralize(route.serviced_units_count, 'unit')
      "#{services} (#{units})"
    end

    def pickups_label
      view.pluralize(route_presenter.pickups_count, 'pickup')
    end

    def gallons_label
      gallons = view.number_to_human(route_presenter.estimated_gallons, units: { unit: 'gal' }, format: '%n %u')
      "#{gallons} pumped"
    end

    def previous_route
      @previous_route
    end

    def next_route
      @next_route
    end

    def navigation_present?
      previous_route.present? || next_route.present? || weather_forecast.present?
    end

    def previous_route_label
      return nil unless previous_route
      view.l(previous_route.route_date, format: '%A, %B %-d')
    end

    def next_route_label
      return nil unless next_route
      view.l(next_route.route_date, format: '%A, %B %-d')
    end

    def weather_forecast
      @weather_forecast
    end

    def weather_forecast_present?
      weather_forecast.present?
    end

    def forecast_high
      forecast_label(:high_temp)
    end

    def forecast_low
      forecast_label(:low_temp)
    end

    def forecast_precip
      return nil unless weather_forecast&.precip_percent.present?
      "#{weather_forecast.precip_percent}% precip"
    end

    def forecast_summary
      weather_forecast&.summary
    end

    private

    attr_reader :route, :view

    def route_presenter
      @route_presenter ||= RoutePresenter.new(route)
    end

    def forecast_label(attribute)
      value = weather_forecast&.public_send(attribute)
      return nil unless value.present?

      {
        text: "#{attribute == :high_temp ? 'High' : 'Low'} #{value}°F",
        css_class: view.freeze_risk_class(value)
      }
    end
  end
end
