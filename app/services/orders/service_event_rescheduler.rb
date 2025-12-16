module Orders
  class ServiceEventRescheduler
    def initialize(order)
      @order = order
    end

    def shift_from(completion_date:)
      interval = Orders::ServiceScheduleResolver.interval_days(order)
      return unless interval

      future_events = order.service_events
                            .where(event_type: ServiceEvent.event_types[:service])
                            .where(ServiceEvent.arel_table[:scheduled_on].gt(Date.current))
                            .order(:scheduled_on)
      return if future_events.blank?

      target_date = completion_date

      future_events.each do |event|
        target_date += interval

        if target_date > order.end_date
          event.destroy
        else
          event.update!(scheduled_on: target_date, route: nil, route_date: target_date)
        end
      end
    end

    private

    attr_reader :order
  end
end
