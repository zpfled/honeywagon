require 'rails_helper'

RSpec.describe Orders::Builder do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:customer) { create(:customer, company_name: 'ACME Events') }
  let(:location) { create(:location, label: 'ACME Wedding Site') }

  let(:start_date) { Date.today }
  let(:end_date)   { Date.today + 7.days }
  let(:weekly_schedule) { RatePlan::SERVICE_SCHEDULES[:weekly] }

  let(:order_params) do
    {
      customer_id: customer.id,
      location_id: location.id,
      start_date: start_date,
      end_date: end_date,
      status: 'draft',
      external_reference: 'PO-123'
    }
  end

  describe '#assign' do
    it 'prevents allocating units that are already assigned to overlapping orders' do
      standard = create(:unit_type, :standard, company: company)

      # 10 standard units in inventory
      create_list(:unit, 10, unit_type: standard, company: company, status: 'available')

      standard_weekly = create(
        :rate_plan,
        unit_type: standard,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 14_000,
        active: true
      )

      # First order takes 4 units in the same date range
      order1 = create(
        :order,
        customer: customer,
        location: location,
        start_date: start_date,
        end_date: end_date,
        status: 'draft',
        external_reference: 'ONE'
      )

      described_class.new(order1).assign(
        params: {
          customer_id: customer.id,
          location_id: location.id,
          start_date: start_date,
          end_date: end_date,
          status: 'draft',
          external_reference: 'ONE'
        },
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 4 }
        ]
      )
      order1.save!
      expect(order1.order_units.count).to eq(4)

      # Second order tries to take 9 more in the same timeframe (should fail: only 6 left)
      order2 = user.orders.new
      order2 = described_class.new(order2).assign(
        params: order_params.merge(external_reference: 'TWO'),
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 9 }
        ]
      )

      expect(order2.errors[:base]).to include(
        "Only 6 Standard Unit units are available for these dates (you requested 9)."
      )
    end

    it 'builds order_units and order_line_items and sets rental_subtotal_cents' do
      standard = create(:unit_type, :standard, company: company)
      ada      = create(:unit_type, :ada, company: company)

      create_list(:unit, 3, unit_type: standard, company: company, status: 'available')
      create_list(:unit, 1, unit_type: ada,      company: company, status: 'available')

      standard_weekly = create(
        :rate_plan,
        unit_type: standard,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 14_000,
        active: true
      )

      ada_weekly = create(
        :rate_plan,
        unit_type: ada,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 18_000,
        active: true
      )

      order = user.orders.new
      builder = described_class.new(order)

      builder.assign(
        params: order_params,
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 2 },
          { unit_type_id: ada.id, rate_plan_id: ada_weekly.id, quantity: 1 }
        ]
      )

      expect(order.errors).to be_empty

      # units assigned
      expect(order.order_units.size).to eq(3)
      order.save
      order.reload
      expect(order.units.count).to eq(3)

      # line items created
      expect(order.order_line_items.size).to eq(2)

      li_standard = order.order_line_items.find { |li| li.unit_type_id == standard.id }
      li_ada      = order.order_line_items.find { |li| li.unit_type_id == ada.id }

      expect(li_standard.rate_plan).to eq(standard_weekly)
      expect(li_standard.quantity).to eq(2)
      expect(li_standard.unit_price_cents).to eq(14_000)
      expect(li_standard.subtotal_cents).to eq(28_000)

      expect(li_ada.rate_plan).to eq(ada_weekly)
      expect(li_ada.quantity).to eq(1)
      expect(li_ada.unit_price_cents).to eq(18_000)
      expect(li_ada.subtotal_cents).to eq(18_000)

      # subtotal rolled up
      expect(order.rental_subtotal_cents).to eq(46_000)
    end

    it 'handles building the first line item without previously used units' do
      standard = create(:unit_type, :standard)
      create_list(:unit, 2, unit_type: standard, status: 'available')

      standard_weekly = create(
        :rate_plan,
        unit_type: standard,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 10_000,
        active: true
      )

      order = user.orders.new
      builder = described_class.new(order)

      expect do
        builder.assign(
          params: order_params,
          unit_type_requests: [
            { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 1 }
          ]
        )
      end.not_to raise_error
    end

    it 'adds a helpful error when requesting more units than available' do
      standard = create(:unit_type, :standard, company: company)
      create_list(:unit, 1, unit_type: standard, company: company, status: 'available')

      standard_weekly = create(
        :rate_plan,
        unit_type: standard,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 14_000,
        active: true
      )

      order = user.orders.new
      builder = described_class.new(order)

      builder.assign(
        params: order_params,
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 3 }
        ]
      )

      expect(order.errors.full_messages.join(' ')).to match(/Only 1 .* available/i)
      expect(order.order_units).to be_empty
      expect(order.order_line_items).to be_empty
      expect(order.rental_subtotal_cents.to_i).to eq(0)
    end

    it 'adds a helpful error when no rate plan exists for the chosen schedule' do
      standard = create(:unit_type, :standard, company: company)
      create_list(:unit, 2, unit_type: standard, company: company, status: 'available')

      # No rate plan created intentionally

      order = user.orders.new
      builder = described_class.new(order)

      builder.assign(
        params: order_params,
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: nil, quantity: 1 }
        ]
      )

      expect(order.errors.full_messages.join(' ')).to match(/rate plan/i)
      expect(order.order_units).to be_empty
      expect(order.order_line_items).to be_empty
    end

    it 'replaces existing units and line items on update' do
      standard = create(:unit_type, :standard, company: company)
      create_list(:unit, 5, unit_type: standard, company: company, status: 'available')

      standard_weekly = create(
        :rate_plan,
        unit_type: standard,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        price_cents: 14_000,
        active: true
      )

      order = create(
        :order,
        customer: customer,
        location: location,
        start_date: start_date,
        end_date: end_date,
        status: 'draft',
        external_reference: 'PO-123'
      )

      # Existing assignment (simulate older state)
      create(:order_unit, order: order, unit: Unit.available_between(start_date, end_date).where(unit_type_id: standard.id).first, placed_on: start_date)
      create(
        :order_line_item,
        order: order,
        unit_type: standard,
        rate_plan: standard_weekly,
        service_schedule: weekly_schedule,
        billing_period: 'monthly',
        quantity: 1,
        unit_price_cents: 14_000,
        subtotal_cents: 14_000
      )

      expect(order.order_units.count).to eq(1)
      expect(order.order_line_items.count).to eq(1)

      builder = described_class.new(order)

      builder.assign(
        params: order_params,
        unit_type_requests: [
          { unit_type_id: standard.id, rate_plan_id: standard_weekly.id, quantity: 3 }
        ]
      )

      expect(order.errors).to be_empty
      expect(order.order_units.size).to eq(3)
      expect(order.order_line_items.size).to eq(1)
      expect(order.order_line_items.first.quantity).to eq(3)
      expect(order.rental_subtotal_cents).to eq(42_000)
    end
  end
end
