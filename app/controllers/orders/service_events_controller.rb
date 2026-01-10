module Orders
  class ServiceEventsController < ApplicationController
    before_action :set_order

    def create
      @service_event = @order.service_events.new(service_event_params.merge(user: current_user, auto_generated: false))

      if @service_event.save
        redirect_to order_path(@order), notice: 'Service event added.'
      else
        redirect_to order_path(@order), alert: @service_event.errors.full_messages.to_sentence
      end
    end

    def destroy
      service_event = @order.service_events.find(params[:id])
      destination_route = service_event.route

      service_event.soft_delete!(user: current_user)

      redirect_to(route_destination(destination_route), notice: 'Service event deleted.')
    rescue ActiveRecord::RecordNotFound
      redirect_to(order_path(@order), alert: 'Service event could not be found.')
    end

    def assign_route
      @service_event = @order.service_events.find(params[:id])
      route = current_user.company.routes.find(params[:route_id])

      if @service_event.scheduled_on.blank?
        return redirect_to(order_path(@order), alert: 'Service event is missing a scheduled date.')
      end

      window = (@service_event.scheduled_on - 14.days)..(@service_event.scheduled_on + 14.days)
      unless window.cover?(route.route_date)
        return redirect_to(order_path(@order), alert: 'Pick a route within 2 weeks of the service date.')
      end

      attrs = {
        route: route,
        route_date: route.route_date,
        scheduled_on: route.route_date
      }

      if @service_event.update(attrs)
        redirect_to(order_path(@order), notice: 'Service event assigned to route.')
      else
        redirect_to(order_path(@order), alert: @service_event.errors.full_messages.to_sentence.presence || 'Unable to assign route.')
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to(order_path(@order), alert: 'Service event or route could not be found.')
    end

    private

    def set_order
      @order = current_user.company.orders.find(params[:order_id])
    end

    def service_event_params
      params.require(:service_event).permit(:event_type, :scheduled_on)
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
