require "rails_helper"

RSpec.describe Routes::BackfillServiceEvents do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  around do |example|
    Routes::ServiceEventRouter.without_auto_assignment { example.run }
  end

  before do
    create(:truck, company: company)
    create(:trailer, company: company)
  end

  it "assigns service events within 2 days to an existing route" do
    route = create(:route, company: company, route_date: Date.today)
    event = create(:service_event, :service, order: create(:order, company: company, created_by: user), scheduled_on: Date.today + 1.day, route: nil)

    assigned, created = described_class.new(company: company).call

    expect(event.reload.route).to eq(route)
    expect(assigned).to eq(1)
    expect(created).to eq(0)
  end

  it "creates new routes for deliveries when no exact route exists" do
    event = create(:service_event, :delivery, order: create(:order, company: company, created_by: user), scheduled_on: Date.tomorrow + 5.days, route: nil)

    assigned, created = described_class.new(company: company).call

    expect(event.reload.route).not_to be_nil
    expect(event.route.route_date).to eq(event.scheduled_on)
    expect(assigned).to eq(1)
    expect(created).to eq(1)
  end
end
