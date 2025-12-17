module Orders
  class ServiceScheduleResolver
    WEEKLY   = RatePlan::SERVICE_SCHEDULES[:weekly].freeze
    BIWEEKLY = RatePlan::SERVICE_SCHEDULES[:biweekly].freeze
    MONTHLY  = RatePlan::SERVICE_SCHEDULES[:monthly].freeze

    def self.schedule_for(order)
      new(order).schedule
    end

    def self.interval_days(order)
      new(order).interval_days
    end

    def initialize(order)
      @order = order
    end

    def schedule
      schedule_from_service_line_items ||
        schedule_from_rental_line_items ||
        RatePlan::SERVICE_SCHEDULES[:none]
    end

    def interval_days
      case schedule
      when WEEKLY   then 7
      when BIWEEKLY then 14
      when MONTHLY  then 30
      else
        nil
      end
    end

    private

    attr_reader :order

    def schedule_from_service_line_items
      item = order.service_line_items.detect { |li| li.service_schedule.present? && li.service_schedule != RatePlan::SERVICE_SCHEDULES[:none] }
      item&.service_schedule
    end

    def schedule_from_rental_line_items
      line_item = order.rental_line_items.detect do |li|
        li.service_schedule.present? && li.service_schedule != RatePlan::SERVICE_SCHEDULES[:none] ||
          li.rate_plan&.service_schedule.present? && li.rate_plan.service_schedule != RatePlan::SERVICE_SCHEDULES[:none]
      end

      return unless line_item

      if line_item.service_schedule.present? && line_item.service_schedule != RatePlan::SERVICE_SCHEDULES[:none]
        line_item.service_schedule
      else
        line_item.rate_plan&.service_schedule
      end
    end
  end
end
