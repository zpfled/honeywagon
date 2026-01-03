require 'rails_helper'

RSpec.describe Routes::DashboardRowPresenter do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, clean_water_capacity_gal: 10, waste_capacity_gal: 10) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 0) }
  let(:route_date) { Date.current + 1.day }
  let(:route) { create(:route, company: company, truck: truck, trailer: trailer, route_date: route_date) }
  let(:order) { create(:order, company: company) }
  let(:waste_load) { { cumulative_used: 40, capacity: 60, remaining: 20, over_capacity: false } }

  subject(:presenter) { described_class.new(route.reload, waste_load: waste_load) }

  before do
    standard_type = create(:unit_type, :standard, company: company)
    create(:rental_line_item, order: order, unit_type: standard_type, quantity: 2)

    delivery = create(:service_event, :delivery,
                      order: order,
                      route: route,
                      route_date: route_date,
                      scheduled_on: route_date)
    delivery.update_column(:route_date, route_date + 1.day)

    create(:service_event, :service,
           order: order,
           route: route,
           scheduled_on: Date.current - 2.days)

    create(:service_event, :service,
           order: order,
           status: :completed,
           completed_on: Date.current - 3.days,
           scheduled_on: Date.current - 3.days)
  end

  it 'generates delivery urgency badges' do
    expect(presenter.delivery_badges).to include(hash_including(text: '1 late', tone: :danger))
  end

  it 'generates service urgency badges' do
    expect(presenter.service_badges).to include(hash_including(text: '1 overdue', tone: :danger))
  end

  it 'summarizes cadence info' do
    cadence = presenter.cadence_info
    expect(cadence[:last_completed_on]).to eq(Date.current - 3.days)
    expect(cadence[:next_due_on]).to eq(Date.current - 2.days)
  end

  it 'exposes capacity icons when limits exceeded' do
    icons = presenter.capacity_icons
    expect(icons.map { |icon| icon[:glyph] }).to include('⛟')
  end

  it 'applies danger row styling when deliveries are late' do
    expect(presenter.row_background_class).to eq('bg-rose-50')
  end

  it 'provides alert badges for the alerts column' do
    texts = presenter.alert_badges.map { |badge| badge[:text] }
    expect(texts).to include('Delivery: 1 late', 'Service: 1 overdue')
  end

  it 'exposes waste load summary when provided' do
    expect(presenter.waste_load_summary).to eq(waste_load)
  end

  it 'includes dump events in the orders summary' do
    dump_site = create(:dump_site, company: company)
    create(:service_event, :dump, route: route, route_date: route_date, dump_site: dump_site)

    summaries = described_class.new(route.reload).orders_summary
    dump_entry = summaries.find { |entry| entry[:dump] }

    expect(dump_entry[:label]).to eq(dump_site.name)
    expect(dump_entry[:detail]).to eq(dump_site.location.display_label)
    expect(dump_entry[:units]).to eq(0)
  end

  it 'shows a completed badge when all events are complete' do
    completed_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current)
    create(:service_event, :delivery,
           order: order,
           route: completed_route,
           route_date: completed_route.route_date,
           scheduled_on: completed_route.route_date,
           status: :completed)
    create(:service_event, :service,
           order: order,
           route: completed_route,
           route_date: completed_route.route_date,
           scheduled_on: completed_route.route_date,
           status: :completed)

    badges = described_class.new(completed_route.reload).alert_badges
    expect(badges).to eq([ { text: 'Completed', tone: :success } ])
  end

  it 'summarizes non-dump orders by customer name and units' do
    customer = create(:customer, company: company, business_name: 'Acme')
    location = create(:location, customer: customer)
    summary_order = create(:order, company: company, customer: customer, location: location)
    unit_type = create(:unit_type, :standard, company: company)
    create(:rental_line_item, order: summary_order, unit_type: unit_type, quantity: 3)
    create(:service_event, :delivery, order: summary_order, route: route, route_date: route_date, scheduled_on: route_date)

    summaries = described_class.new(route.reload).orders_summary
    entry = summaries.find { |row| row[:label] == customer.display_name }

    expect(entry[:label]).to eq(customer.display_name)
    expect(entry[:units]).to eq(3)
  end

  it 'returns lightweight trend badges based on service event count' do
    light_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current + 2.days)
    create(:service_event, :delivery, order: order, route: light_route, route_date: light_route.route_date, scheduled_on: light_route.route_date)
    create(:service_event, :service, order: order, route: light_route, route_date: light_route.route_date, scheduled_on: light_route.route_date)

    heavy_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current + 3.days)
    5.times do
      create(:service_event, :service, order: order, route: heavy_route, route_date: heavy_route.route_date, scheduled_on: heavy_route.route_date)
    end

    expect(described_class.new(light_route.reload).trend_badge).to include(text: '↓ light route')
    expect(described_class.new(heavy_route.reload).trend_badge).to include(text: '↑ heavy route')
  end

  it 'returns on-schedule badge when there are no events' do
    empty_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current + 4.days)
    badges = described_class.new(empty_route).alert_badges

    expect(badges).to eq([ { text: 'On schedule', tone: :success } ])
  end

  it 'fetches weather forecast for a route with a geocoded location' do
    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: 43.1, lng: -89.4)
    forecast_order = create(:order, company: company, customer: customer, location: location)
    create(:service_event, :delivery, order: forecast_order, route: route, route_date: route_date, scheduled_on: route_date)

    forecast = Struct.new(:high_temp, :low_temp, :precip_percent, :summary).new(80, 60, 10, 'Sunny')
    allow(Weather::ForecastFetcher).to receive(:call).and_return(forecast)

    expect(presenter.weather_forecast).to eq(forecast)
  end

  it 'returns unit counts for delivery, service, and pickup events' do
    count_route = create(:route, company: company, truck: truck, trailer: trailer, route_date: Date.current + 5.days)
    count_order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    create(:rental_line_item, order: count_order, unit_type: unit_type, quantity: 2)
    create(:service_event, :delivery, order: count_order, route: count_route, route_date: count_route.route_date, scheduled_on: count_route.route_date)
    create(:service_event, :pickup, order: count_order, route: count_route, route_date: count_route.route_date, scheduled_on: count_route.route_date)
    create(:service_event, :service, order: count_order, route: count_route, route_date: count_route.route_date, scheduled_on: count_route.route_date)

    count_presenter = described_class.new(count_route.reload)
    expect(count_presenter.deliveries_count).to eq(2)
    expect(count_presenter.pickups_count).to eq(2)
    expect(count_presenter.services_count).to eq(2)
  end
end
