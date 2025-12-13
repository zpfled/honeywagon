module Routes
  class ServiceEventsController < ApplicationController
    before_action :set_route
    before_action :set_service_event

    def postpone
      next_route = find_or_create_next_route

      if next_route
        @service_event.update!(route: next_route, route_date: next_route.route_date)
        redirect_to route_path(next_route), notice: 'Service event postponed to the next route.'
      else
        redirect_to route_path(@route), alert: 'Unable to postpone service event.'
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to route_path(@route), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_route
      @route = current_user.company.routes.find(params[:route_id])
    end

    def set_service_event
      @service_event = @route.service_events.find(params[:id])
    end

    def find_or_create_next_route
      company = current_user.company
      next_route = company.routes.where('route_date > ?', @route.route_date).order(:route_date).first
      return next_route if next_route

      company.routes.create(route_date: @route.route_date + 1.day)
    end
  end
end
