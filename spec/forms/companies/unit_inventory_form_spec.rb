require "rails_helper"

RSpec.describe Companies::UnitInventoryForm do
  let(:company) { create(:company) }
  let(:unit_type) { create(:unit_type, company: company) }

  it "adds units when the target exceeds current" do
    form = described_class.new(
      company: company,
      params: { unit_type_id: unit_type.id, quantity: 2 }
    )

    expect { form.call }.to change { unit_type.units.count }.from(0).to(2)
  end

  it "raises when removing more units than available" do
    create(:unit, unit_type: unit_type, company: company, status: "available")
    create(:unit, unit_type: unit_type, company: company, status: "rented")

    form = described_class.new(
      company: company,
      params: { unit_type_id: unit_type.id, quantity: 0 }
    )

    expect { form.call }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
