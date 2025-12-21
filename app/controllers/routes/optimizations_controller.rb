class Routes::OptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_route

  def create
    result = Routes::Optimization::Run.call(@route)

    if result.success?
      @route.resequence_service_events!(result.event_ids_in_order)
      flash[:notice] = ([ 'Optimization result:' ] + result.warnings).join('<br>').html_safe
    else
      flash[:alert] = result.errors.join('<br>').html_safe
    end

    redirect_to route_path(@route)
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:route_id])
  end
end
