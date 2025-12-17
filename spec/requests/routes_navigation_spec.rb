require 'rails_helper'

RSpec.describe 'Routes navigation', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let!(:route_prev) { create(:route, company: company, route_date: Date.current - 1) }
  let!(:route_current) { create(:route, company: company, route_date: Date.current) }
  let!(:route_next) { create(:route, company: company, route_date: Date.current + 1) }

  before { sign_in user }

  it 'renders previous and next links on the route show page' do
    get route_path(route_current)

    prev_label = I18n.l(route_prev.route_date, format: "%A, %B %-d")
    next_label = I18n.l(route_next.route_date, format: "%A, %B %-d")

    expect(response.body).to include("← #{prev_label}")
    expect(response.body).to include("#{next_label} →")
  end
end
