class Routes::OrderingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_route

  def update
    ordered_ids = Array(params[:event_ids]).map(&:presence).compact
    manual_result = Routes::Optimization::ManualRun.call(@route, ordered_ids)
    @route.resequence_service_events!(ordered_ids)

    if manual_result.success?
      flash[:notice] = ([ 'Route updated:' ] + manual_result.warnings).join(' ').html_safe
    else
      flash[:alert] = ([ 'Route order saved, but optimization skipped:' ] + manual_result.errors).join(' ').html_safe
    end

    redirect_to route_path(@route)
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:route_id])
  end
end
