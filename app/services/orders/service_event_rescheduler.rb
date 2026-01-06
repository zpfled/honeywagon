module Orders
  class ServiceEventRescheduler
    def initialize(order)
      @order = order
    end

    def shift_from(completion_date:)
      # Determine the cadence for future service events based on the order schedule.
      interval = Orders::ServiceScheduleResolver.interval_days(order)
      return unless interval

      # Only adjust upcoming service events; completed or past ones stay as-is.
      future_events = order.service_events
                            .where(event_type: ServiceEvent.event_types[:service])
                            .where(ServiceEvent.arel_table[:scheduled_on].gt(Date.current))
                            .order(:scheduled_on)
      return if future_events.blank?

      # Start rescheduling from the completion date, advancing by the cadence each time.
      target_date = completion_date

      future_events.each do |event|
        target_date += interval

        if target_date > order.end_date
          # Drop events that would fall beyond the rental window.
          event.destroy
        else
          # Update date and clear routing so it can be re-assigned.
          event.update!(scheduled_on: target_date, route: nil, route_date: target_date)
        end
      end

      # Reassign any unrouted events to appropriate routes once dates are updated.
      Routes::BackfillServiceEvents.new(company: order.company).call
    end

    private

    attr_reader :order
  end
end
