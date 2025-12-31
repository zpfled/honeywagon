module Routes
  class DumpEventsController < ApplicationController
    before_action :set_route

    def create
      # TODO: View reads:
      # - None (redirect only).
      # TODO: Changes needed:
      # - None.
      dump_site = current_user.company.dump_sites.find_by(id: dump_event_params[:dump_site_id])
      unless dump_site
        return redirect_to route_path(@route), alert: 'Select a valid dump site.'
      end

      event_type = ServiceEventType.find_by!(key: 'dump')
      event = ServiceEvent.new(
        event_type: :dump,
        service_event_type: event_type,
        route: @route,
        route_date: @route.route_date,
        scheduled_on: @route.route_date,
        user: current_user,
        dump_site: dump_site
      )

      if event.save
        redirect_to route_path(@route), notice: 'Dump event scheduled on this route.'
      else
        redirect_to route_path(@route), alert: event.errors.full_messages.to_sentence.presence || 'Unable to schedule dump event.'
      end
    end

    private

    def set_route
      @route = current_user.company.routes.find(params[:route_id])
    end

    def dump_event_params
      params.fetch(:dump_event, {}).permit(:dump_site_id)
    end
  end
end
