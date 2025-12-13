class RoutesController < ApplicationController
  before_action :set_route, only: %i[show update]

  def index
    @routes = current_user.company.routes.order(route_date: :desc)
    @route = current_user.company.routes.new(route_date: Date.current)
  end

  def show
    @service_events = @route.service_events.includes(order: [ :customer, :location ])
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
      @service_events = @route.service_events.includes(order: [ :customer, :location ])
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:id])
  end

  def route_params
    params.require(:route).permit(:route_date)
  end
end
