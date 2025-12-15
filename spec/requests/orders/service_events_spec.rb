require 'rails_helper'

RSpec.describe "Order service events management", type: :request do
  let(:user) { create(:user) }
  let(:order) { create(:order, company: user.company, created_by: user) }
  let!(:service_event) { create(:service_event, order: order, user: user) }

  before { sign_in user }

  it "soft deletes the service event" do
    delete order_service_event_path(order, service_event)

    expect(response).to redirect_to(order_path(order))

    deleted_record = ServiceEvent.with_deleted.find(service_event.id)
    expect(deleted_record.deleted_at).to be_present
    expect(deleted_record.deleted_by).to eq(user)
  end

  it "handles missing events gracefully" do
    delete order_service_event_path(order, SecureRandom.uuid)

    expect(response).to redirect_to(order_path(order))
    follow_redirect!
    expect(response.body).to include('could not be found')
  end
end
