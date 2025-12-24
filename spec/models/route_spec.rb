require 'rails_helper'

RSpec.describe Route do
  describe 'callbacks' do
    let(:company) { create(:company) }
    let(:user) { create(:user, company: company) }
    let!(:truck) { create(:truck, company: company) }
    let!(:trailer) { create(:trailer, company: company) }

    it 'assigns scheduled service events in the same week when created' do
      order = create(:order, company: company, created_by: user, status: 'scheduled', start_date: Date.today, end_date: Date.today + 3.days)
      event = nil
      Routes::ServiceEventRouter.without_auto_assignment do
        event = create(:service_event, :service, order: order, scheduled_on: Date.today.beginning_of_week + 1.day)
        create(:service_event, :service, order: order, scheduled_on: Date.today.beginning_of_week - 1.day)
      end

      route = described_class.create!(company: company, route_date: Date.today.beginning_of_week, truck: truck, trailer: trailer)

      expect(route.service_events).to include(event)
      expect(event.reload.route_date).to eq(route.route_date)
    end

    it 'updates service event route_date when route date changes' do
      route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.today)
      event = create(:service_event, :service, route: route, order: create(:order, company: company, created_by: user, start_date: Date.today, end_date: Date.today + 1.day, status: 'scheduled'), scheduled_on: Date.today)
      route.update!(route_date: Date.today + 2.days)

      expect(event.reload.route_date).to eq(route.route_date)
    end
  end

  describe '#serviced_units_count' do
    it 'includes service line items in addition to rental units' do
      route = create(:route)
      order = create(:order, company: route.company, status: 'scheduled')
      unit_type = create(:unit_type, :standard, company: route.company)
      rate_plan = create(:rate_plan, unit_type: unit_type)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)
      create(:service_line_item, order: order, units_serviced: 3)

      create(:service_event, :service, order: order, route: route, route_date: route.route_date)

      expect(route.serviced_units_count).to eq(5)
    end
  end

  describe '#estimated_gallons' do
    it 'sums event estimates including overrides' do
      route = create(:route)
      order = create(:order, company: route.company, status: 'scheduled')
      event_with_override = create(:service_event, :service, order: order, route: route, route_date: route.route_date, estimated_gallons_override: 25)
      order2 = create(:order, company: route.company, status: 'scheduled')
      create(:service_line_item, order: order2, units_serviced: 2)
      event_with_service_units = create(:service_event, :service, order: order2, route: route, route_date: route.route_date)

      expect(route.estimated_gallons).to eq(event_with_override.estimated_gallons_pumped + event_with_service_units.estimated_gallons_pumped)
    end
  end

  describe 'auto-destroy when empty' do
    it 'removes the route once all service events are gone' do
      route = create(:route)
      order = create(:order, company: route.company, status: 'scheduled')
      create(:service_event, :service, route: route, order: order, route_date: route.route_date)

      expect { route.service_events.destroy_all }.to change { Route.count }.by(-1)
      expect(Route.find_by(id: route.id)).to be_nil
    end
  end

  describe '#record_stop_drive_metrics' do
    let(:route) { create(:route) }
    let!(:events) { Array.new(5) { create(:service_event, route: route, route_date: route.route_date) } }
    let(:event_ids) { events.map(&:id) }
    let(:legs) do
      [
        { distance_meters: 1470, duration_seconds: 161 },
        { distance_meters: 6899, duration_seconds: 504 },
        { distance_meters: 29426, duration_seconds: 1186 },
        { distance_meters: 3058, duration_seconds: 205 }
      ]
    end

    it 'assigns per-leg drive distance and duration based on provided legs' do
      route.record_stop_drive_metrics(event_ids: event_ids, legs: legs)

      expect(events[0].reload.drive_distance_meters).to eq(0)
      expect(events[0].drive_duration_seconds).to eq(0)

      expect(events[1].reload.drive_distance_meters).to eq(1470)
      expect(events[1].drive_duration_seconds).to eq(161)

      expect(events[3].reload.drive_distance_meters).to eq(29426)
      expect(events[3].drive_duration_seconds).to eq(1186)

      expect(events[4].reload.drive_distance_meters).to eq(3058)
      expect(events[4].drive_duration_seconds).to eq(205)
    end

    it 'defaults to zero metrics when a leg is missing' do
      route.record_stop_drive_metrics(event_ids: event_ids, legs: legs.first(2))

      expect(events[4].reload.drive_distance_meters).to eq(0)
      expect(events[4].drive_duration_seconds).to eq(0)
    end

    it 'assigns the first leg when the route begins at a base location' do
      base_legs = [
        { distance_meters: 500, duration_seconds: 60 },
        { distance_meters: 1000, duration_seconds: 120 },
        { distance_meters: 1500, duration_seconds: 180 }
      ]
      route.record_stop_drive_metrics(event_ids: event_ids.first(2), legs: base_legs)

      expect(events[0].reload.drive_distance_meters).to eq(500)
      expect(events[1].reload.drive_distance_meters).to eq(1000)
    end
  end
end
