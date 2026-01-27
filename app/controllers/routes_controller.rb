class RoutesController < ApplicationController
  before_action :set_route, only: %i[update push_to_calendar merge]
  before_action :set_route_with_service_events, only: %i[show]
  before_action :load_fleet_assets, only: %i[show update]

  def show
    load_route_details
  end

  def calendar
    @calendar_start = calendar_start_date
    @calendar_end = @calendar_start + 27.days
    company = current_user.company
    @routes = company.routes
                         .includes(:truck, :trailer, :service_events)
                         .where(route_date: @calendar_start..@calendar_end)
                         .order(:route_date, :id)
    @routes_by_date = @routes.group_by(&:route_date)
    @forecast_by_date = calendar_forecasts(company)
  end

  def create
    @route = current_user.company.routes.new(route_params)

    if @route.save
      redirect_to @route, notice: 'Route created.'
    else
      redirect_back fallback_location: authenticated_root_path,
                    alert: @route.errors.full_messages.to_sentence
    end
  end

  def update
    #   @route_summary, @dump_sites, @stop_presenters
    if @route.update(route_params)
      redirect_to @route, notice: 'Route updated.'
    else
      load_route_details
      render :show, status: :unprocessable_content
    end
  end

  def push_to_calendar
    result = Routes::GoogleCalendarPusher.new(route: @route, user: current_user).call

    if result.success?
      redirect_to @route, notice: 'Route pushed to Google Calendar.'
    else
      redirect_to @route, alert: result.errors.to_sentence
    end
  end

  def merge
    target = current_user.company.routes.find(params[:target_id])
    result = Routes::MergeService.call(source: @route, target: target)

    if result.success?
      render json: { status: 'ok' }
    else
      render json: { status: 'error', errors: result.errors }, status: :unprocessable_content
    end
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:id])
  end

  def set_route_with_service_events
    @route = current_user.company.routes.includes(:service_events).find(params[:id])
  end

  def load_route_details
    presenter = Routes::DetailPresenter.new(@route, company: current_user.company)
    @service_events = presenter.service_events
    @stop_presenters = presenter.stop_presenters
    @map_stops = presenter.map_stops
    @previous_route = presenter.previous_route
    @next_route = presenter.next_route
    @waste_load = presenter.waste_load
    @capacity_steps = presenter.capacity_steps
    @dump_sites = current_user.company.dump_sites.includes(:location)
    @weather_forecast = presenter.weather_forecast
    @route_summary = Routes::ShowSummaryPresenter.new(route: @route, waste_load: @waste_load)
    @route_header = Routes::ShowHeaderPresenter.new(
      route: @route,
      previous_route: @previous_route,
      next_route: @next_route,
      weather_forecast: @weather_forecast,
      view_context: view_context
    )
  end

  def load_fleet_assets
    company = current_user.company
    @trucks = company.trucks.order(:name, :number)
    @trailers = company.trailers.order(:name, :identifier)
  end

  def route_params
    params.require(:route).permit(:route_date, :truck_id, :trailer_id)
  end

  def calendar_start_date
    seed = params[:start].presence
    date = seed ? Date.parse(seed) : Date.current
    date.beginning_of_week(:sunday)
  rescue ArgumentError
    Date.current.beginning_of_week(:sunday)
  end

  def calendar_forecasts(company)
    location = company.home_base
    return {} unless location&.lat.present? && location&.lng.present?

    forecasts = {}
    @calendar_start.upto(@calendar_end) do |date|
      forecast = Weather::ForecastFetcher.call(
        company: company,
        date: date,
        latitude: location.lat,
        longitude: location.lng
      )
      forecasts[date] = forecast if forecast.present?
    end
    forecasts
  end
end
