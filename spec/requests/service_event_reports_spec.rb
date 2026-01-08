require 'rails_helper'

RSpec.describe "ServiceEventReports", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:order) { create(:order, company: user.company, created_by: user, status: 'scheduled') }
  let(:route) { create(:route, company: user.company) }
  let(:service_event) { create(:service_event, :service, order: order, user: user, route: route, route_date: route.route_date) }

  before do
    sign_in user
  end

  it 'stores estimated gallons override when creating a report' do
    post service_event_reports_path, params: {
      service_event_id: service_event.id,
      service_event_report: { estimated_gallons_pumped: 55, units_pumped: 2 }
    }

    expect(response).to redirect_to(route_path(service_event.route))
    expect(service_event.reload.estimated_gallons_override).to eq(55)
  end

  it 'updates the override when editing a report' do
    service_event.update!(status: :completed)
    report = service_event.service_event_report
    report.update!(data: { 'estimated_gallons_pumped' => 15 })

    patch service_event_report_path(report), params: {
      service_event_report: { estimated_gallons_pumped: 80 },
      redirect_path: service_event_reports_path
    }

    expect(service_event.reload.estimated_gallons_override).to eq(80)
  end

  it 'completes the order when reporting a pickup event' do
    travel_to Date.new(2024, 6, 12) do
      pickup_order = create(:order, company: user.company, created_by: user, status: 'active')
      pickup_event = create(:service_event, :pickup, order: pickup_order, user: user, scheduled_on: Date.current)

      post service_event_reports_path, params: {
        service_event_id: pickup_event.id,
        service_event_report: { estimated_gallons_pumped: 12 }
      }

      pickup_order.reload
      expect(pickup_order.status).to eq('completed')
      expect(pickup_order.end_date).to eq(Date.new(2024, 6, 12))
    end
  end
end
