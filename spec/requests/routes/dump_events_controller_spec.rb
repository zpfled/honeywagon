require 'rails_helper'

RSpec.describe 'Routes::DumpEventsController', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company, route_date: Date.current) }
  let(:dump_site) { create(:dump_site, company: company) }

  before do
    create(:service_event_type_dump)
    sign_in user
  end

  describe 'POST /routes/:route_id/dump_events' do
    it 'creates a dump event on the route' do
      expect do
        post route_dump_events_path(route), params: { dump_event: { dump_site_id: dump_site.id } }
      end.to change { ServiceEvent.where(event_type: :dump).count }.by(1)

      expect(response).to redirect_to(route_path(route))
      event = ServiceEvent.order(:created_at).last
      expect(event.dump_site).to eq(dump_site)
      expect(event.order).to be_nil
      expect(flash[:notice]).to eq('Dump event scheduled on this route.')
    end

    it 'rejects unknown dump sites' do
      post route_dump_events_path(route), params: { dump_event: { dump_site_id: SecureRandom.uuid } }

      expect(response).to redirect_to(route_path(route))
      expect(flash[:alert]).to eq('Select a valid dump site.')
    end
  end
end
