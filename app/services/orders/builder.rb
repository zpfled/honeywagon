module Orders
  # Builder orchestrates converting the order form input into concrete units and
  # pricing line items while validating availability and rate plans.
  class Builder
    attr_reader :order

    # Stores the order being mutated during the assignment flow.
    def initialize(order)
      @order = order
    end

    # unit_type_requests format:
    # [
    #   { unit_type_id: 1, rate_plan_id: 5, quantity: 3 },
    #   { unit_type_id: 2, rate_plan_id: 7, quantity: 1 }
    # ]
    # Applies params/unit-type requests to the order, enforcing availability and
    # populating order_units + order_line_items.
    def assign(params:, unit_type_requests:)
      order.assign_attributes(params)

      if order.start_date.blank? || order.end_date.blank?
        order.errors.add(:base, 'Set a start and end date before assigning units.')
        return order
      end

      existing_rate_plan_ids = order.order_line_items.map(&:rate_plan_id).compact

      new_order_units, new_line_items = build_units_and_line_items(
        unit_type_requests,
        existing_rate_plan_ids: existing_rate_plan_ids
      )

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

    # Builds in-memory order_units and order_line_items for the request payload.
    def build_units_and_line_items(unit_type_requests, existing_rate_plan_ids:)
      order_units = []
      line_items  = []

      used_unit_ids = []

      Array(unit_type_requests).each do |req|
        qty = req[:quantity].to_i
        next if qty <= 0

        unit_type_id = req[:unit_type_id] || req['unit_type_id']
        rate_plan_id = req[:rate_plan_id] || req['rate_plan_id']

        if rate_plan_id.blank?
          order.errors.add(:base, 'Select a rate plan for each line item.')
          break
        end

        rate_plan = RatePlan.includes(:unit_type).find_by(id: rate_plan_id)

        unless rate_plan
          order.errors.add(:base, 'Rate plan could not be found.')
          break
        end

        if !rate_plan.active? && !existing_rate_plan_ids.include?(rate_plan.id)
          order.errors.add(:base, 'Rate plan is no longer active.')
          break
        end

        unit_type = rate_plan.unit_type

        if unit_type_id.present? && unit_type.id.to_s != unit_type_id.to_s
          order.errors.add(:base, 'Rate plan does not match the selected unit type.')
          break
        end

        schedule = rate_plan.service_schedule

        # Availability: choose actual units to assign
        available_scope = Unit.available_between(order.start_date, order.end_date)
                              .where(unit_type_id: unit_type.id, company_id: order.company_id)
        if used_unit_ids.any?
          available_scope = available_scope.where.not(id: used_unit_ids)
        end
        available_units = available_scope.limit(qty).to_a


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
            placed_on: order.start_date,
            billing_period: rate_plan.billing_period
          )
          used_unit_ids << unit.id
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
    # Calculates the subtotal in cents for a line item given its rate plan.
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
