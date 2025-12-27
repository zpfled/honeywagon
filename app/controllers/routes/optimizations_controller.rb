class Routes::OptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_route

  def create
    result = Routes::Optimization::Run.call(@route)

    if result.success?
      @route.resequence_service_events!(result.event_ids_in_order)
      @route.record_stop_drive_metrics(event_ids: result.event_ids_in_order, legs: result.legs)
      if result.duration_seconds.present? || result.distance_meters.present?
        @route.record_drive_metrics(seconds: result.duration_seconds, meters: result.distance_meters)
      else
        @route.update!(optimization_stale: false)
      end
      flash[:notice] = ([ 'Route optimized:' ] + result.warnings).join(' ').html_safe
    else
      flash[:alert] = result.errors.join(' ').html_safe
    end

    # TODO: delegate sequencing/metrics persistence to a service (ApplyResult) to keep controller skinny
    redirect_to route_path(@route)
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:route_id])
  end
end
