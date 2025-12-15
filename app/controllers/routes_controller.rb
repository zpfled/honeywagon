class RoutesController < ApplicationController
  before_action :set_route, only: %i[show update]
  before_action :load_fleet_assets, only: %i[index create show update]

  def index
    @routes = current_user.company.routes.includes(:truck, :trailer,
                                                   service_events: { order: { rental_line_items: :unit_type } })
                          .order(route_date: :desc)
    @route = current_user.company.routes.new(
      route_date: Date.current,
      truck: @trucks.first,
      trailer: @trailers.first
    )
  end

  def show
    @service_events = @route.service_events.includes(order: [ :customer, :location, { rental_line_items: :unit_type } ])
  end

  def create
    @route = current_user.company.routes.new(route_params)

    if @route.save
      redirect_to @route, notice: 'Route created.'
    else
      @routes = current_user.company.routes.order(route_date: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @route.update(route_params)
      redirect_to @route, notice: 'Route updated.'
    else
      @service_events = @route.service_events.includes(order: [ :customer, :location, { rental_line_items: :unit_type } ])
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:id])
  end

  def load_fleet_assets
    @trucks = current_user.company.trucks.order(:name, :number)
    @trailers = current_user.company.trailers.order(:name, :identifier)
  end

  def route_params
    params.require(:route).permit(:route_date, :truck_id, :trailer_id)
  end
end
