require 'rails_helper'

RSpec.describe Routes::ShowSummaryPresenter do
  it 'formats usage labels and classes' do
    company = create(:company)
    truck = create(:truck, company: company, clean_water_capacity_gal: 10, waste_capacity_gal: 10)
    trailer = create(:trailer, company: company, capacity_spots: 1)
    route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current)
    order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, unit_type: unit_type, company: company)
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, quantity: 2)
    create(:service_event, :service, order: order, route: route, route_date: route.route_date, scheduled_on: route.route_date)

    presenter = described_class.new(route: route)

    expect(presenter.trailer_usage_label).to include('/')
    expect(presenter.clean_usage_label).to include('gal')
    expect(presenter.waste_usage_label).to include('gal')
    expect(presenter.drive_label).to be_nil
  end
end
