require 'rails_helper'

RSpec.describe 'Routes::ServiceEventsController#complete', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:route) { create(:route, company: company) }
  let(:order) { create(:order, company: company, created_by: user) }
  let(:service_event) { create(:service_event, order: order, route: route, route_date: route.route_date) }

  before { sign_in user }

  it 'marks the service event as completed' do
    post complete_route_service_event_path(route, service_event)

    expect(response).to redirect_to(route_path(route))
    expect(flash[:notice]).to eq('Service event marked completed.')
    expect(service_event.reload).to be_status_completed
  end

  it 'surfaces validation errors' do
    allow_any_instance_of(ServiceEvent).to receive(:update).and_return(false)
    allow_any_instance_of(ServiceEvent).to receive(:errors).and_return(double(full_messages_to_sentence: 'Error'))

    post complete_route_service_event_path(route, service_event)

    expect(response).to redirect_to(route_path(route))
    expect(flash[:alert]).to eq('Error')
  end
end
