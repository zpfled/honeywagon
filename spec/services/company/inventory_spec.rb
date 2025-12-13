require 'rails_helper'

RSpec.describe Company::Inventory do
  let(:company) { create(:company) }
  let(:standard_type) { create(:unit_type, :standard, company: company) }
  let(:rate_plan_monthly) { create(:rate_plan, unit_type: standard_type, billing_period: 'monthly') }
  let(:rate_plan_event) { create(:rate_plan, unit_type: standard_type, billing_period: 'per_event') }
  let(:user) { create(:user, company: company) }
  let!(:units) { create_list(:unit, 4, unit_type: standard_type, company: company, status: 'available') }
  let(:inventory) { described_class.new(company: company) }

  describe '#rented_count and #available_count' do
    it 'counts only attached units on blocking orders overlapping the window' do
      blocking_order = create(:order, company: company, created_by: user, status: 'scheduled', start_date: Date.today, end_date: Date.today + 7.days)
      create(:order_line_item, order: blocking_order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 3)

      units.first(2).each do |unit|
        create(:order_unit, order: blocking_order, unit: unit, placed_on: blocking_order.start_date, billing_period: 'monthly')
      end

      non_blocking_order = create(:order, company: company, created_by: user, status: 'draft', start_date: Date.today, end_date: Date.today + 7.days)
      create(:order_line_item, order: non_blocking_order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 1)
      create(:order_unit, order: non_blocking_order, unit: units.third, placed_on: non_blocking_order.start_date, billing_period: 'monthly')

      future_order = create(:order, company: company, created_by: user, status: 'scheduled', start_date: Date.today + 30.days, end_date: Date.today + 37.days)
      create(:order_line_item, order: future_order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 1)
      create(:order_unit, order: future_order, unit: units.fourth, placed_on: future_order.start_date, billing_period: 'monthly')

      rented_now = inventory.rented_count(unit_type: standard_type)
      available_now = inventory.available_count(unit_type: standard_type)
      rented_future = inventory.rented_count(unit_type: standard_type, start_date: Date.today + 30.days, end_date: Date.today + 37.days)

      expect(rented_now).to eq(2)
      expect(available_now).to eq(2)
      expect(rented_future).to eq(1)
    end
  end

  describe '#rental_count_for_period' do
    it 'counts only attached units for each billing period' do
      monthly_order = create(:order, company: company, created_by: user, status: 'scheduled')
      create(:order_line_item, order: monthly_order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 3)
      units.first(2).each do |unit|
        create(:order_unit, order: monthly_order, unit: unit, placed_on: monthly_order.start_date, billing_period: 'monthly')
      end

      event_order = create(:order, company: company, created_by: user, status: 'scheduled')
      create(:order_line_item, order: event_order, unit_type: standard_type, rate_plan: rate_plan_event, billing_period: 'per_event', quantity: 2)
      create(:order_unit, order: event_order, unit: units.third, placed_on: event_order.start_date, billing_period: 'per_event')

      future_order = create(:order, company: company, created_by: user, status: 'scheduled', start_date: Date.today + 30.days, end_date: Date.today + 37.days)
      create(:order_line_item, order: future_order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 1)
      create(:order_unit, order: future_order, unit: units.fourth, placed_on: future_order.start_date, billing_period: 'monthly')

      expect(inventory.rental_count_for_period(unit_type: standard_type, billing_period: :monthly)).to eq(2)
      expect(inventory.rental_count_for_period(unit_type: standard_type, billing_period: :per_event)).to eq(1)
      expect(
        inventory.rental_count_for_period(
          unit_type: standard_type,
          billing_period: :monthly,
          start_date: Date.today + 30.days,
          end_date: Date.today + 37.days
        )
      ).to eq(1)
    end
  end

  describe 'mixed billing periods' do
    it 'does not double count monthly and event units on the same order' do
      order = create(:order, company: company, created_by: user, status: 'scheduled')
      create(:order_line_item, order: order, unit_type: standard_type, rate_plan: rate_plan_monthly, billing_period: 'monthly', quantity: 2)
      create(:order_line_item, order: order, unit_type: standard_type, rate_plan: rate_plan_event, billing_period: 'per_event', quantity: 1)

      create(:order_unit, order: order, unit: units[0], placed_on: order.start_date, billing_period: 'monthly')
      create(:order_unit, order: order, unit: units[1], placed_on: order.start_date, billing_period: 'monthly')
      create(:order_unit, order: order, unit: units[2], placed_on: order.start_date, billing_period: 'per_event')

      expect(inventory.rented_count(unit_type: standard_type)).to eq(3)
      expect(inventory.rental_count_for_period(unit_type: standard_type, billing_period: :monthly)).to eq(2)
      expect(inventory.rental_count_for_period(unit_type: standard_type, billing_period: :per_event)).to eq(1)
    end
  end

  describe 'availability counts' do
    it 'includes non-retired statuses and excludes retired units' do
      maintenance_unit = create(:unit, company: company, unit_type: standard_type, status: 'maintenance')
      retired_unit = create(:unit, company: company, unit_type: standard_type, status: 'retired')

      expect(inventory.available_count(unit_type: standard_type)).to eq(units.size + 1) # maintenance + base units
      expect(
        company.units.assignable
               .merge(Unit.available_between(Date.current, Date.current))
      ).not_to include(retired_unit)
    end
  end
end
