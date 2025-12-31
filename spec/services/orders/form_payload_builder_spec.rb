require 'rails_helper'

RSpec.describe Orders::FormPayloadBuilder do
  it 'builds unit type payload with a service-only entry' do
    company = create(:company)
    unit_type = create(:unit_type, company: company, name: 'Standard Unit')
    order = create(:order, company: company)

    payload = described_class.new(
      order: order,
      unit_types: [ unit_type ],
      service_rate_plans: [],
      company_id: company.id
    ).call

    expect(payload[:unit_type_payload]).to include(id: unit_type.id, name: unit_type.name)
    expect(payload[:unit_type_payload]).to include(id: 'service-only', name: 'Service-only (customer-owned units)')
  end

  it 'includes inactive rate plans referenced by existing line items' do
    company = create(:company)
    unit_type = create(:unit_type, company: company)
    active_plan = create(:rate_plan, unit_type: unit_type, company: company)
    inactive_plan = create(:rate_plan, :inactive, unit_type: unit_type, company: company)
    order = create(:order, company: company)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: inactive_plan)

    payload = described_class.new(
      order: order,
      unit_types: [ unit_type ],
      service_rate_plans: [],
      company_id: company.id
    ).call

    ids = payload[:rate_plan_payload][unit_type.id].map { |entry| entry[:id] }
    expect(ids).to include(active_plan.id, inactive_plan.id)
  end

  it 'captures service line items and rate plan labels' do
    company = create(:company)
    order = create(:order, company: company)
    service_plan = create(:rate_plan, unit_type: nil, company: company, service_schedule: RatePlan::SERVICE_SCHEDULES[:event])
    create(:service_line_item, order: order, rate_plan: service_plan, description: 'Extra service', units_serviced: 2)

    payload = described_class.new(
      order: order,
      unit_types: [],
      service_rate_plans: [ service_plan ],
      company_id: company.id
    ).call

    item = payload[:service_items_payload].first
    expect(item[:rate_plan_label]).to eq(service_plan.display_label)
    expect(payload[:service_rate_plans_payload].first[:id]).to eq(service_plan.id)
  end
end
