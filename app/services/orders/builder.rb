module Orders
  class Builder
    attr_reader :order

    def initialize(order)
      @order = order
    end

    # unit_type_requests format:
    # {
    #   "1" => { quantity: 3, service_schedule: "weekly" },
    #   "2" => { quantity: 1, service_schedule: "event" }
    # }
    def assign(params:, unit_type_requests:)
      order.assign_attributes(params)

      if order.start_date.blank? || order.end_date.blank?
        order.errors.add(:base, 'Set a start and end date before assigning units.')
        return order
      end

      new_order_units, new_line_items = build_units_and_line_items(unit_type_requests)

      return order if order.errors.any?

      # Replace assignments only after validation passes
      if order.persisted?
        order.order_units.destroy_all
        order.order_line_items.destroy_all
      end

      new_order_units.each { |ou| order.order_units << ou }
      new_line_items.each  { |li| order.order_line_items << li }

      # Basic subtotal from line items (no proration yet)
      order.rental_subtotal_cents = new_line_items.sum(&:subtotal_cents)

      # Let your existing callback/method handle total math (fees/discount/tax)
      order.recalculate_totals

      order
    end

    private

    def build_units_and_line_items(unit_type_requests)
      order_units = []
      line_items  = []

      unit_type_requests.each do |unit_type_id_str, req|
        qty = req[:quantity].to_i
        next if qty <= 0

        schedule = req[:service_schedule].to_s
        unit_type = UnitType.find(unit_type_id_str)

        rate_plan = RatePlan.active.find_by(
          unit_type_id: unit_type.id,
          service_schedule: schedule
        )

        unless rate_plan
          order.errors.add(:base, "No active rate plan found for #{unit_type.name} (#{schedule}).")
          break
        end

        # Availability: choose actual units to assign
        available_units = Unit.available_between(order.start_date, order.end_date)
                      .where(unit_type_id: unit_type.id)
                      .limit(qty)
                      .to_a


        if available_units.size < qty
          order.errors.add(
            :base,
            "Only #{available_units.size} #{unit_type.name} units are available " \
            "for these dates (you requested #{qty})."
          )
          break
        end

        available_units.each do |unit|
          order_units << OrderUnit.new(
            order: order,
            unit: unit,
            placed_on: order.start_date
          )
        end

        unit_price_cents = rate_plan.price_cents
        subtotal_cents   = compute_subtotal(rate_plan: rate_plan, quantity: qty)

        line_items << OrderLineItem.new(
          order: order,
          unit_type: unit_type,
          rate_plan: rate_plan,
          service_schedule: rate_plan.service_schedule,
          billing_period: rate_plan.billing_period,
          quantity: qty,
          unit_price_cents: unit_price_cents,
          subtotal_cents: subtotal_cents
        )
      end

      [ order_units, line_items ]
    end

    # For now:
    # - monthly: charge one month
    # - per_event: charge once
    def compute_subtotal(rate_plan:, quantity:)
      case rate_plan.billing_period
      when 'monthly'
        quantity * rate_plan.price_cents
      when 'per_event'
        quantity * rate_plan.price_cents
      else
        # keep it strict so you notice new billing types immediately
        order.errors.add(:base, "Unknown billing period: #{rate_plan.billing_period}")
        0
      end
    end
  end
end
