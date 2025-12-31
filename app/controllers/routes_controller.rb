class RoutesController < ApplicationController
  before_action :set_route, only: %i[show update]
  before_action :load_fleet_assets, only: %i[index create show update]

  def index
    # TODO: View reads:
    # - @route (new Route for form)
    # - @trucks, @trailers (fleet dropdowns)
    # - @route_rows (Routes::IndexPresenter rows; row.route, row counts, over_capacity badges)
    # TODO: Changes needed:
    # - Ensure preloads cover row presenter usage (service_events -> order -> rental_line_items -> unit_type, plus truck/trailer).
    # - Move per-row label formatting (over-capacity dimension text) into presenter.
    @routes = current_user.company.routes.includes(:truck, :trailer,
                                                   service_events: { order: [ { rental_line_items: :unit_type } ] })
                          .order(route_date: :desc)
    @route_rows = Routes::IndexPresenter.new(@routes).rows
    @route = current_user.company.routes.new(
      route_date: Date.current,
      truck: @trucks.first,
      trailer: @trailers.first
    )
  end

  def show
    # TODO: View reads:
    # - @route (header counts, form)
    # - @trucks, @trailers (edit form)
    # - @previous_route, @next_route (navigation)
    # - @weather_forecast (forecast panel)
    # - @route_summary (capacity/drive summary)
    # - @dump_sites (dump-site selector; uses dump_site.location)
    # - @stop_presenters (route stops table)
    # TODO: Changes needed:
    # - Move header/forecast/summary computations into presenters (reduce inline view logic).
    # - Ensure stop presenters are built from preloaded data (orders, customers, locations, dump sites).
    load_route_details
  end

  def create
    # TODO: View reads (on failure render :index):
    # - Same as index: @route, @trucks, @trailers, @route_rows
    # TODO: Changes needed:
    # - Ensure index preloads still applied on error branch.
    @route = current_user.company.routes.new(route_params)

    if @route.save
      redirect_to @route, notice: 'Route created.'
    else
      @routes = current_user.company.routes.includes(:truck, :trailer,
                                                     service_events: { order: [ { rental_line_items: :unit_type } ] })
                            .order(route_date: :desc)
      @route_rows = Routes::IndexPresenter.new(@routes).rows
      render :index, status: :unprocessable_entity
    end
  end

  def update
    # TODO: View reads (on failure render :show):
    # - Same as show: @route, @trucks, @trailers, @previous_route, @next_route, @weather_forecast,
    #   @route_summary, @dump_sites, @stop_presenters
    # TODO: Changes needed:
    # - Ensure load_route_details keeps view-only aggregation out of controller.
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
    @stop_presenters = presenter.stop_presenters
    @previous_route = presenter.previous_route
    @next_route = presenter.next_route
    @waste_load = presenter.waste_load
    @capacity_steps = presenter.capacity_steps
    @dump_sites = current_user.company.dump_sites.includes(:location)
    @weather_forecast = presenter.weather_forecast
    @route_presenter = RoutePresenter.new(@route)
    @route_summary = Routes::ShowSummaryPresenter.new(route: @route, waste_load: @waste_load)
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
