require 'rails_helper'

RSpec.describe Company do
  describe '#units_rented_count and #units_available_count' do
    let(:company) { create(:company) }
    let(:unit_type) { create(:unit_type, :standard, company: company) }
    let(:rate_plan) { create(:rate_plan, unit_type: unit_type, billing_period: 'monthly') }
    let(:user) { create(:user, company: company) }

    before do
      create_list(:unit, 3, unit_type: unit_type, company: company, status: 'available')
    end

    it 'returns counts based on actual assigned units' do
      order = create(:order, user: user, status: 'scheduled')
      create(:order_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)

      Unit.where(unit_type: unit_type).limit(2).each do |unit|
        create(:order_unit, order: order, unit: unit, placed_on: order.start_date)
      end

      expect(company.units_rented_count(unit_type)).to eq(2)
      expect(company.units_available_count(unit_type)).to eq(1)
    end
  end
end
