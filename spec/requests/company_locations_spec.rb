require "rails_helper"

RSpec.describe "/company/locations", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "renders the locations list with missing coordinates badge" do
    customer = create(:customer, company: user.company)
    location = create(:location, customer: customer, lat: nil, lng: nil)

    get locations_company_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Locations")
    expect(response.body).to include(location.display_label)
    expect(response.body).to include("Missing coordinates")
  end
end
