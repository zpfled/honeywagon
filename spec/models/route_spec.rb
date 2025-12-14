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
end
