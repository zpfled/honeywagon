module Routes
  class ServiceEventsController < ApplicationController
    before_action :set_route
    before_action :set_service_event

    def postpone
      result = Routes::ServiceEventMover.new(@service_event).move_to_next
      redirect_with_result(result)
    end

    def advance
      result = Routes::ServiceEventMover.new(@service_event).move_to_previous
      redirect_with_result(result)
    end

    def complete
      result = Routes::ServiceEventCompleter.new(@service_event).call
      redirect_with_result(result)
    end

    def destroy
      @service_event.soft_delete!(user: current_user)
      redirect_to route_path(@route), notice: 'Service event deleted.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to route_path(@route), alert: e.message
    end

    private

    def set_route
      @route = current_user.company.routes.find(params[:route_id])
    end

    def set_service_event
      @service_event = @route.service_events.find(params[:id])
    end

    def redirect_with_result(result)
      flash_type = result.success? ? :notice : :alert
      redirect_to route_path(result.route || @route), flash_type => result.message
    end
  end
end
