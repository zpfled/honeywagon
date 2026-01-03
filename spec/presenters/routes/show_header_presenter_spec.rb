require 'rails_helper'

RSpec.describe Routes::ShowHeaderPresenter do
  let(:view_context) do
    Class.new do
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::NumberHelper
      include ActionView::Helpers::TranslationHelper
      include UiHelper
    end.new
  end

  it 'formats header labels and navigation data' do
    company = create(:company)
    route_date = Date.new(2024, 1, 1)
    route = create(:route, company: company, route_date: route_date)
    previous_route = create(:route, company: company, route_date: route_date - 1.day)
    next_route = create(:route, company: company, route_date: route_date + 1.day)
    order = create(:order, company: company)
    unit_type = create(:unit_type, :standard, company: company)
    create(:rental_line_item, order: order, unit_type: unit_type, quantity: 2)
    create(:service_event, :service, order: order, route: route, route_date: route_date, scheduled_on: route_date)

    forecast = Struct.new(:high_temp, :low_temp, :precip_percent, :summary).new(25, 5, 10, 'Cold')

    presenter = described_class.new(
      route: route,
      previous_route: previous_route,
      next_route: next_route,
      weather_forecast: forecast,
      view_context: view_context
    )

    expect(presenter.route_date_label).to eq(view_context.l(route_date, format: '%A, %B %-d'))
    expect(presenter.deliveries_label).to eq('0 deliveries')
    expect(presenter.services_label).to eq('1 service (2 units)')
    expect(presenter.pickups_label).to eq('0 pickups')
    expect(presenter.gallons_label).to eq("#{view_context.number_to_human(20, units: { unit: 'gal' }, format: '%n %u')} pumped")
    expect(presenter.previous_route_label).to eq(view_context.l(previous_route.route_date, format: '%A, %B %-d'))
    expect(presenter.next_route_label).to eq(view_context.l(next_route.route_date, format: '%A, %B %-d'))
    expect(presenter.forecast_high[:text]).to eq('High 25°F')
    expect(presenter.forecast_low[:text]).to eq('Low 5°F')
    expect(presenter.forecast_precip).to eq('10% precip')
    expect(presenter.forecast_summary).to eq('Cold')
  end
end
