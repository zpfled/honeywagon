require 'rails_helper'

RSpec.describe 'Company expenses', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before { sign_in user }

  it 'creates an expense via company update' do
    patch company_path, params: {
      expense: {
        name: 'Fuel',
        category: 'fuel',
        cost_type: 'per_mile',
        base_amount: '4.25',
        applies_to: [ 'all' ]
      }
    }
    expect(response).to redirect_to(edit_company_path)
    expect(company.expenses.count).to eq 1
  end
end
