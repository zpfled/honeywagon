require "rails_helper"

RSpec.describe ServiceEvent, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  describe ".upcoming_week" do
    it "returns scheduled events through the next week, including overdue ones, ordered by date" do
      travel_to Date.new(2024, 5, 6) do
        overdue = create(:service_event, scheduled_on: Date.new(2024, 5, 4), status: :scheduled)
        upcoming = create(:service_event, scheduled_on: Date.new(2024, 5, 8), status: :scheduled)
        create(:service_event, scheduled_on: Date.new(2024, 5, 14), status: :scheduled) # beyond horizon
        create(:service_event, scheduled_on: Date.new(2024, 5, 7), status: :completed) # completed excluded

        expect(described_class.upcoming_week).to eq([ overdue, upcoming ])
      end
    end
  end

  describe "reports" do
    include ActiveSupport::Testing::TimeHelpers

    it "creates a report when a reportable event is completed" do
      type = create(:service_event_type_service)
      event = create(:service_event, :service, service_event_type: type, status: :scheduled)

      event.update!(status: :completed)

      expect(event.service_event_report).to be_present
      expect(event.service_event_report.data["customer_name"]).to eq(event.order.customer.display_name)
    end

    it "does not create a report for non-reportable events" do
      type = create(:service_event_type_delivery)
      event = create(:service_event, :delivery, service_event_type: type, status: :scheduled)

      event.update!(status: :completed)

      expect(event.service_event_report).to be_nil
    end
  end

  describe 'completed_on tracking' do
    it 'stamps completed_on when event is completed' do
      event = create(:service_event, status: :scheduled)
      freeze_time do
        event.update!(status: :completed)
        expect(event.completed_on).to eq(Date.current)
      end
    end
  end

  describe '#estimated_gallons_pumped' do
    it 'uses override when present' do
      event = create(:service_event, estimated_gallons_override: 25)
      expect(event.estimated_gallons_pumped).to eq(25)
    end

    it 'returns zero for delivery events' do
      event = create(:service_event, :delivery)
      expect(event.estimated_gallons_pumped).to eq(0)
    end

    it 'returns 10 gallons per ADA/standard unit for service/pickup events' do
      order = create(:order, status: 'scheduled')
      unit_type = create(:unit_type, :standard, company: order.company)
      rate_plan = create(:rate_plan, unit_type: unit_type)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 3)

      event = create(:service_event, :service, order: order)

      expect(event.estimated_gallons_pumped).to eq(30)
    end

    it 'includes service line items for service events' do
      order = create(:order, status: 'scheduled')
      create(:service_line_item, order: order, units_serviced: 2)

      event = create(:service_event, :service, order: order)

      expect(event.estimated_gallons_pumped).to eq(20)
    end
  end

  describe 'truck waste load maintenance' do
    it 'recalculates truck load when override changes' do
      truck = create(:truck, waste_capacity_gal: 200)
      route = create(:route, truck: truck, company: truck.company)
      order = create(:order, company: route.company, status: 'scheduled')
      event = create(:service_event, :service, order: order, route: route, route_date: route.route_date, status: :completed)

      event.update!(estimated_gallons_override: 40)

      expect(truck.reload.waste_load_gal).to eq(40)

      event.update!(estimated_gallons_override: 60)

      expect(truck.reload.waste_load_gal).to eq(60)
    end
  end

  describe '#units_impacted_count' do
    it 'counts rental units for deliveries and pickups' do
      order = create(:order, status: 'scheduled')
      unit_type = create(:unit_type, :standard, company: order.company)
      rate_plan = create(:rate_plan, unit_type: unit_type)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 4)

      delivery_event = create(:service_event, :delivery, order: order)
      pickup_event = create(:service_event, :pickup, order: order)

      expect(delivery_event.units_impacted_count).to eq(4)
      expect(pickup_event.units_impacted_count).to eq(4)
    end

    it 'includes service line item units for service events' do
      order = create(:order, status: 'scheduled')
      create(:service_line_item, order: order, units_serviced: 2)

      event = create(:service_event, :service, order: order)

      expect(event.units_impacted_count).to eq(2)
    end

    it 'sums rental and service units for service events' do
      order = create(:order, status: 'scheduled')
      unit_type = create(:unit_type, :standard, company: order.company)
      rate_plan = create(:rate_plan, unit_type: unit_type)
      create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 3)
      create(:service_line_item, order: order, units_serviced: 2)

      event = create(:service_event, :service, order: order)

      expect(event.units_impacted_count).to eq(5)
    end
  end

  describe 'dump events' do
    it 'require a dump site' do
      event = build(:service_event, :dump, dump_site: nil)
      expect(event).not_to be_valid
      expect(event.errors[:dump_site]).to include("can't be blank")
    end

    it 'allow events without an order' do
      event = build(:service_event, :dump)
      event.order = nil
      expect(event).to be_valid
    end

    it 'impact zero units' do
      event = create(:service_event, :dump)
      expect(event.units_impacted_count).to eq(0)
    end

    it 'reset truck load when completed' do
      truck = create(:truck, waste_capacity_gal: 200)
      route = create(:route, company: truck.company, truck: truck, route_date: Date.current)
      order = create(:order, company: truck.company, status: 'scheduled')
      create(:service_event, :service, order: order, route: route, route_date: route.route_date, status: :completed, estimated_gallons_override: 50)
      dump_site = create(:dump_site, company: truck.company)
      dump_event = create(:service_event, :dump, route: route, route_date: route.route_date, dump_site: dump_site)

      expect(truck.reload.waste_load_gal).to eq(50)

      dump_event.update!(status: :completed)
      truck.recalculate_waste_load!

      expect(truck.reload.waste_load_gal).to eq(0)
    end
  end
  describe "route auto-assignment" do
    it "assigns a newly created event to a nearby route" do
      company = create(:company)
      create(:truck, company: company)
      create(:trailer, company: company)
      route = create(:route, company: company, route_date: Date.today + 1.day)
      order = create(:order, company: company)

      event = create(:service_event, :service, order: order, scheduled_on: route.route_date, route: nil)

      expect(event.reload.route).to eq(route)
    end
  end

  describe '#overdue?' do
    include ActiveSupport::Testing::TimeHelpers

    it 'returns true for scheduled service events in the past' do
      travel_to Date.new(2024, 1, 10) do
        event = create(:service_event, :service, scheduled_on: Date.new(2024, 1, 5), status: :scheduled)
        expect(event).to be_overdue
        expect(event.days_overdue).to eq(5)
      end
    end

    it 'returns false for completed events' do
      travel_to Date.new(2024, 1, 10) do
        event = create(:service_event, :service, scheduled_on: Date.new(2024, 1, 5), status: :completed)
        expect(event).not_to be_overdue
      end
    end

    it 'flags delivery events whose route date is after the scheduled date' do
      travel_to Date.new(2024, 1, 10) do
        route = create(:route, route_date: Date.new(2024, 1, 10))
        event = create(:service_event, :delivery, scheduled_on: Date.new(2024, 1, 10), route: route, route_date: route.route_date)
        event.update_column(:route_date, Date.new(2024, 1, 12))
        expect(event.reload).to be_overdue
        expect(event.days_overdue).to eq(2)
      end
    end

    it 'does not flag delivery events when route date is on or before schedule' do
      route = create(:route, route_date: Date.current)
      event = create(:service_event, :delivery, scheduled_on: Date.current, route: route, route_date: route.route_date)
      expect(event).not_to be_overdue
    end
  end

  describe 'logistics schedule enforcement' do
    it 'prevents delivery events from moving later than scheduled' do
      route = create(:route, route_date: Date.current + 1.day)
      order = create(:order, company: route.company, status: 'scheduled', start_date: Date.current, end_date: Date.current + 5.days)

      event = build(:service_event, :delivery, order: order, route: route, scheduled_on: Date.current, route_date: Date.current + 1.day)

      expect(event).not_to be_valid
      expect(event.errors[:route_date]).to include('cannot be after the scheduled date for deliveries')
    end

    it 'prevents pickup events from moving earlier than scheduled' do
      route = create(:route, route_date: Date.current)
      order = create(:order, company: route.company, status: 'scheduled', start_date: Date.current - 5.days, end_date: Date.current)

      event = build(:service_event, :pickup, order: order, route: route, scheduled_on: Date.current, route_date: Date.current - 1.day)

      expect(event).not_to be_valid
      expect(event.errors[:route_date]).to include('cannot be before the scheduled date for pickups')
    end
  end
end
