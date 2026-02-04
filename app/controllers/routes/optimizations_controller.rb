class Routes::OptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_route

  def create
    puts("[route optimization] start route_id=#{@route.id} service_events=#{@route.service_events.size}")
    result = Routes::Optimization::Run.call(@route)
    puts("[route optimization] result success=#{result.success?} warnings=#{Array(result.warnings).size} errors=#{Array(result.errors).size}")
    puts("[route optimization] ordered_event_ids=#{Array(result.event_ids_in_order).join(',')}")
    puts("[route optimization] distance_meters=#{result.distance_meters.inspect} duration_seconds=#{result.duration_seconds.inspect}")

    if result.success?
      puts("[route optimization] applying resequence + drive metrics")
      @route.resequence_service_events!(result.event_ids_in_order)
      @route.record_stop_drive_metrics(event_ids: result.event_ids_in_order, legs: result.legs)
      if result.duration_seconds.present? || result.distance_meters.present?
        @route.record_drive_metrics(seconds: result.duration_seconds, meters: result.distance_meters)
      else
        @route.update!(optimization_stale: false)
      end
      flash[:notice] = ([ 'Route optimized:' ] + result.warnings).join(' ').html_safe
    else
      puts("[route optimization] failed errors=#{Array(result.errors).join(' | ')}")
      flash[:alert] = result.errors.join(' ').html_safe
    end

    redirect_to route_path(@route)
  end

  private

  def set_route
    @route = current_user.company.routes.find(params[:route_id])
  end
end
