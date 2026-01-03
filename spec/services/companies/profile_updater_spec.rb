require "rails_helper"

RSpec.describe Companies::ProfileUpdater do
  let(:company) { create(:company, name: "Original Name") }
  let(:unit_type) { create(:unit_type, company: company) }

  def build_service(overrides = {})
    defaults = {
      company: company,
      company_params: {},
      truck_params: {},
      trailer_params: {},
      customer_params: {},
      unit_type_params: {},
      rate_plan_params: {},
      dump_site_params: {},
      expense_params: {},
      unit_inventory_params: {}
    }

    described_class.new(**defaults.merge(overrides))
  end

  it "updates and creates records in one transaction" do
    result = build_service(
      company_params: { name: "Updated Name" },
      truck_params: {
        name: "Truck A",
        number: "1",
        clean_water_capacity_gal: 0,
        waste_capacity_gal: 0
      }
    ).call

    expect(result.success?).to be(true)
    expect(company.reload.name).to eq("Updated Name")
    expect(company.trucks.count).to eq(1)
  end

  it "rolls back when a form fails" do
    result = build_service(
      company_params: { name: "Updated Name" },
      unit_inventory_params: { unit_type_id: unit_type.id, quantity: -1 }
    ).call

    expect(result.success?).to be(false)
    expect(result.error_record).to eq(unit_type)
    expect(company.reload.name).to eq("Original Name")
  end
end
