module Orders
  class FormPayloadBuilder
    def initialize(order:, unit_types:, service_rate_plans:, company_id:)
      @order = order
      @unit_types = Array(unit_types).compact
      @service_rate_plans = Array(service_rate_plans).compact
      @company_id = company_id
    end

    def call
      {
        unit_types: unit_types,
        unit_type_payload: unit_type_payload,
        unit_type_payload_json: json_escape(unit_type_payload),
        existing_line_items_payload: existing_line_items_payload,
        existing_line_items_payload_json: json_escape(existing_line_items_payload),
        rate_plan_payload: rate_plan_payload,
        rate_plan_payload_json: json_escape(rate_plan_payload),
        service_items_payload: service_items_payload,
        service_items_payload_json: json_escape(service_items_payload),
        service_rate_plans_payload: service_rate_plans_payload,
        service_rate_plans_payload_json: json_escape(service_rate_plans_payload)
      }
    end

    private

    attr_reader :order, :service_rate_plans, :company_id

    def unit_types
      @unit_types
    end

    def unit_type_payload
      payload = unit_types.map { |unit_type| { id: unit_type.id, name: unit_type.name } }
      payload << { id: 'service-only', name: 'Service-only (customer-owned units)' }
      payload
    end

    def existing_line_items_payload
      order.rental_line_items.map do |line_item|
        {
          unit_type_id: line_item.unit_type_id,
          rate_plan_id: line_item.rate_plan_id,
          quantity: line_item.quantity
        }
      end
    end

    def rate_plan_payload
      plans = rate_plans_for_view
      plans.group_by(&:unit_type_id).transform_values do |grouped|
        grouped.sort_by { |plan| [ plan.billing_period.to_s, plan.service_schedule.to_s ] }.map do |plan|
          { id: plan.id, label: plan.display_label }
        end
      end
    end

    def service_items_payload
      order.service_line_items.map do |item|
        {
          description: item.description,
          service_schedule: item.service_schedule,
          units_serviced: item.units_serviced,
          rate_plan_id: item.rate_plan_id,
          rate_plan_label: item.rate_plan&.display_label || 'Service plan'
        }
      end
    end

    def service_rate_plans_payload
      service_rate_plans.map do |plan|
        {
          id: plan.id,
          label: plan.display_label,
          schedule: plan.service_schedule
        }
      end
    end

    def rate_plans_for_view
      active_plans = RatePlan.active.rental.where(company_id: company_id).to_a
      missing_ids = existing_line_items_payload.map { |entry| entry[:rate_plan_id] }.compact - active_plans.map(&:id)
      missing_plans = missing_ids.any? ? RatePlan.where(id: missing_ids).to_a : []
      (active_plans + missing_plans).uniq { |plan| plan.id }
    end

    def json_escape(payload)
      ERB::Util.json_escape(ActiveSupport::JSON.encode(payload))
    end
  end
end
