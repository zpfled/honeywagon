module Orders
  class ServiceEventsController < ApplicationController
    before_action :set_order

    def destroy
      service_event = @order.service_events.find(params[:id])
      destination_route = service_event.route

      service_event.soft_delete!(user: current_user)

      redirect_to(route_destination(destination_route), notice: 'Service event deleted.')
    rescue ActiveRecord::RecordNotFound
      redirect_to(order_path(@order), alert: 'Service event could not be found.')
    end

    private

    def set_order
      @order = current_user.company.orders.find(params[:order_id])
    end

    def route_destination(route)
      if route.present?
        route_path(route)
      else
        order_path(@order)
      end
    end
  end
end
