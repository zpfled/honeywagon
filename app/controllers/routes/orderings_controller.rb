class Routes::OrderingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_route

  def update
    ordered_ids = Array(params[:event_ids]).map(&:presence).compact
    # TODO: delegate sequencing/metrics application to a dedicated service to keep controller thin
    result = Routes::Optimization::ManualRun.call(@route, ordered_ids)

    if result.success?
      @route.resequence_service_events!(ordered_ids)
      flash[:notice] = ([ 'Route updated:' ] + result.warnings).join(' ').html_safe
    else
      flash[:alert] = result.errors.join(' ').html_safe
    end

    redirect_to route_path(@route)
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:route_id])
  end
end
