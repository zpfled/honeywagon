require 'rails_helper'

RSpec.describe Dashboard::InventoryMetrics do
  describe '#call' do
    let(:company) { create(:company) }
    let(:standard) { create(:unit_type, :standard, company: company) }
    let(:ada) { create(:unit_type, :ada, company: company) }
    let(:rate_plan_monthly) { create(:rate_plan, unit_type: standard, billing_period: 'monthly') }
    let(:rate_plan_event) { create(:rate_plan, unit_type: standard, billing_period: 'per_event') }
    let(:user) { create(:user, company: company) }

    before do
      create_list(:unit, 5, unit_type: standard, company: company, status: 'available')
      create_list(:unit, 2, unit_type: ada, company: company, status: 'available')
    end

    it 'counts only actual units assigned to active orders for monthly and event rentals' do
      order = create(:order, user: user, status: 'scheduled', start_date: Date.today, end_date: Date.today + 7.days)
      create(:order_line_item, order: order, unit_type: standard, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 2)

      units = Unit.where(unit_type: standard).limit(3)
      units.first(2).each do |unit|
        create(:order_unit, order: order, unit: unit, placed_on: order.start_date, billing_period: 'monthly')
      end

      event_order = create(:order, user: user, status: 'scheduled', start_date: Date.today, end_date: Date.today + 3.days)
      create(:order_line_item, order: event_order, unit_type: standard, rate_plan: rate_plan_event, billing_period: 'per_event', quantity: 1)
      create(:order_unit, order: event_order, unit: units.third, placed_on: event_order.start_date, billing_period: 'per_event')

      orphan_order = create(:order, user: user, status: 'scheduled', start_date: Date.today, end_date: Date.today + 4.days)
      create(:order_line_item, order: orphan_order, unit_type: standard, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 5)

      metrics = described_class.new(company: company).call
      stats = metrics[:inventory_stats].find { |row| row[:unit_type] == standard }

      expect(stats[:total_units]).to eq(5)
      expect(stats[:available_units]).to eq(2)
      expect(stats[:rented_units]).to eq(3)
      expect(stats[:monthly_out]).to eq(2)
      expect(stats[:event_out]).to eq(1)
    end
  end
end
