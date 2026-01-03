require "rails_helper"

RSpec.describe Companies::RatePlanRowsPresenter do
  it "combines unit type and service-only rate plans into rows" do
    company = create(:company)
    unit_type = create(:unit_type, company: company)
    unit_plan = create(:rate_plan, company: company, unit_type: unit_type)
    service_plan = create(:rate_plan, company: company, unit_type: nil)

    presenter = described_class.new(
      unit_types: [ unit_type ],
      service_rate_plans: [ service_plan ]
    )

    expect(presenter.rows).to eq([ [ unit_type, unit_plan ], [ nil, service_plan ] ])
  end
end
