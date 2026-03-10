require 'rails_helper'

RSpec.describe Routes::ServiceEventUncompleter do
  let(:company) { create(:company) }
  let(:route) { create(:route, company: company, route_date: Date.current) }
  let(:order) { create(:order, company: company, created_by: create(:user, company: company)) }

  def call_service_event(event)
    described_class.new(event).call
  end

  it 'uncompletes a completed service event without any report' do
    event = create(
      :service_event,
      :delivery,
      order: order,
      route: route,
      scheduled_on: route.route_date,
      status: :completed
    )

    result = call_service_event(event)

    expect(result).to be_success
    expect(result.message).to eq('Service event marked not completed.')
    expect(event.reload).to be_status_scheduled
    expect(event.completed_on).to be_nil
  end

  it 'uncompletes a completed service event with a zero-gallon report' do
    event = create(:service_event, :service, order: order, route: route)
    event.update!(status: :completed)
    event.service_event_report.update!(data: { estimated_gallons_pumped: '0' })

    result = call_service_event(event)

    expect(result).to be_success
    expect(result.route).to eq(route)
    expect(event.reload).to be_status_scheduled
  end

  it 'prevents uncompleting when gallons are positive' do
    event = create(:service_event, :service, order: order, route: route)
    event.update!(status: :completed)
    event.service_event_report.update!(data: { estimated_gallons_pumped: '7' })

    result = call_service_event(event)

    expect(result.success?).to be(false)
    expect(result.message).to eq('This service event cannot be uncompleted because it has a completed service log with gallons recorded.')
    expect(event.reload).to be_status_completed
  end

  it 'prevents uncompleting a dump event with positive dumped gallons' do
    event = create(:service_event, :dump, route: route)
    event.update!(status: :completed)
    event.service_event_report.update!(data: { estimated_gallons_dumped: '20' })

    result = call_service_event(event)

    expect(result).not_to be_success
    expect(event.reload).to be_status_completed
  end

  it 'rejects uncompleting a non-completed event' do
    event = create(:service_event, :service, order: order, route: route, status: :scheduled)

    result = call_service_event(event)

    expect(result.success?).to be(false)
    expect(result.message).to eq('Only completed service events can be uncompleted.')
    expect(event.reload).to be_status_scheduled
  end
end
