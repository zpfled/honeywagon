require 'rails_helper'

RSpec.describe 'Orders availability', type: :request do
  let(:user) { create(:user) }
  let(:company) { user.company }
  let(:unit_type) { create(:unit_type, company: company) }
  let!(:available_unit) { create(:unit, company: company, unit_type: unit_type, status: 'available') }
  let!(:blocked_unit) { create(:unit, company: company, unit_type: unit_type, status: 'available') }
  let!(:maintenance_unit) { create(:unit, company: company, unit_type: unit_type, status: 'maintenance') }
  let!(:order) do
    create(:order,
           company: company,
           status: 'scheduled',
           start_date: Date.current,
           end_date: Date.current + 3.days)
  end
  let!(:order_unit) { create(:order_unit, order: order, unit: blocked_unit) }

  before { sign_in user }

  it 'returns available counts' do
    get availability_orders_path, params: { start_date: Date.current, end_date: Date.current + 1.day }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    entry = payload['availability'].find { |row| row['name'] == unit_type.name }
    expect(entry['available']).to eq(1)
  end

  it 'requires valid dates' do
    get availability_orders_path, params: { start_date: '', end_date: '' }

    expect(response).to have_http_status(:unprocessable_entity)
    payload = JSON.parse(response.body)
    expect(payload['error']).to be_present
  end
end
