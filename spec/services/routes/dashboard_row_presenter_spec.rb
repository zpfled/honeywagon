require 'rails_helper'

RSpec.describe Routes::DashboardRowPresenter do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company, clean_water_capacity_gal: 10, septage_capacity_gal: 10) }
  let(:trailer) { create(:trailer, company: company, capacity_spots: 0) }
  let(:route_date) { Date.current + 1.day }
  let(:route) { create(:route, company: company, truck: truck, trailer: trailer, route_date: route_date) }
  let(:order) { create(:order, company: company) }
  let(:septage_load) { { cumulative_used: 40, capacity: 60, remaining: 20, over_capacity: false } }

  subject(:presenter) { described_class.new(route.reload, septage_load: septage_load) }

  before do
    standard_type = create(:unit_type, :standard, company: company)
    create(:rental_line_item, order: order, unit_type: standard_type, quantity: 2)

    create(:service_event, :delivery,
           order: order,
           route: route,
           route_date: route_date + 1.day,
           scheduled_on: Date.current)

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
    expect(texts).to include('1 late', '1 overdue')
  end

  it 'exposes septage load summary when provided' do
    expect(presenter.septage_load_summary).to eq(septage_load)
  end
end
