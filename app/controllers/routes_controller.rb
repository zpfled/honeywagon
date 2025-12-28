class RoutesController < ApplicationController
  before_action :set_route, only: %i[show update]
  before_action :load_fleet_assets, only: %i[index create show update]

  def index
    @routes = current_user.company.routes.includes(:truck, :trailer,
                                                   service_events: { order: [ :location, { rental_line_items: :unit_type } ] })
                          .order(route_date: :desc)
    @route_rows = Routes::IndexPresenter.new(@routes).rows
    @route = current_user.company.routes.new(
      route_date: Date.current,
      truck: @trucks.first,
      trailer: @trailers.first
    )
  end

  def show
    load_route_details
  end

  def create
    @route = current_user.company.routes.new(route_params)

    if @route.save
      redirect_to @route, notice: 'Route created.'
    else
      @routes = current_user.company.routes.includes(:truck, :trailer,
                                                     service_events: { order: [ :location, { rental_line_items: :unit_type } ] })
                            .order(route_date: :desc)
      @route_rows = Routes::IndexPresenter.new(@routes).rows
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @route.update(route_params)
      redirect_to @route, notice: 'Route updated.'
    else
      load_route_details
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:id])
  end

  def load_route_details
    # TODO: Expose stop presenters from Routes::DetailPresenter to remove view logic.
    presenter = Routes::DetailPresenter.new(@route, company: current_user.company)
    @service_events = presenter.service_events
    @previous_route = presenter.previous_route
    @next_route = presenter.next_route
    @waste_load = presenter.waste_load
    @capacity_steps = presenter.capacity_steps
    @dump_sites = current_user.company.dump_sites.includes(:location)
    @weather_forecast = presenter.weather_forecast
    @route_presenter = RoutePresenter.new(@route)
  end

  def load_fleet_assets
    company = current_user.company
    @trucks = company.trucks.order(:name, :number)
    @trailers = company.trailers.order(:name, :identifier)
  end

  def route_params
    params.require(:route).permit(:route_date, :truck_id, :trailer_id)
  end
end
