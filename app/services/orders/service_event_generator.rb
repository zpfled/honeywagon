module Orders
  # ServiceEventGenerator builds the system-generated lifecycle events (delivery,
  # recurring service, pickup) for a given order. Replace-all strategy: delete any
  # previously auto-generated events for the order, then rebuild them so rerunning
  # the generator stays idempotent.
  class ServiceEventGenerator
    # @param order [Order] the order whose events should be generated
    def initialize(order)
      @order = order
    end

    # Builds the required service events for the order, replacing existing
    # auto-generated rows so the method remains idempotent.
    def call
      return if order.start_date.blank? || order.end_date.blank?

      order.with_lock do
        order.service_events.auto_generated.delete_all
        build_events.each do |attrs|
          order.service_events.create!(
            attrs.merge(status: :scheduled, auto_generated: true)
          )
        end
      end
    end

    private

    attr_reader :order

    # Returns the full ordered list of event attribute hashes that should exist.
    def build_events
      (mandatory_events + recurring_service_events).sort_by { |attrs| attrs[:scheduled_on] }
    end

    # Delivery/pickup events are always present, regardless of schedule.
    def mandatory_events
      [
        { event_type: :delivery, scheduled_on: order.start_date },
        { event_type: :pickup, scheduled_on: order.end_date }
      ]
    end

    # Returns recurring service events based on the order's effective schedule.
    def recurring_service_events
      interval_days = recurring_interval_days
      return [] unless interval_days

      events = []
      current_date = order.start_date + interval_days

      while current_date < order.end_date
        # Skip dates that collide with delivery or pickup; we don't want duplicate
        # events for the same day.
        unless [ order.start_date, order.end_date ].include?(current_date)
          events << { event_type: :service, scheduled_on: current_date }
        end
        current_date += interval_days
      end

      events
    end

    # Maps the effective schedule string to a recurrence interval in days.
    def recurring_interval_days
      case effective_service_schedule
      when RatePlan::SERVICE_SCHEDULES[:weekly]
        7
      when RatePlan::SERVICE_SCHEDULES[:biweekly]
        14
      else
        nil
      end
    end

    # Derives the service schedule from the line items or their rate plans.
    def effective_service_schedule
      line_item = line_item_with_schedule
      line_item&.service_schedule.presence ||
        line_item&.rate_plan&.service_schedule.presence ||
        RatePlan::SERVICE_SCHEDULES[:none]
    end

    # Picks the first line item that declares a schedule directly or via rate plan.
    def line_item_with_schedule
      order.order_line_items.detect do |line_item|
        line_item.service_schedule.present? || line_item.rate_plan&.service_schedule.present?
      end
    end
  end
end
