require 'rails_helper'
require 'nokogiri'

RSpec.describe "Order line item form behaviour", type: :request do
  let(:user) { create(:user) }
  let(:customer) { create(:customer) }
  let(:location) { create(:location, customer: customer) }
  let(:unit_type) { create(:unit_type, :standard, company: user.company) }
  let(:rate_plan) { create(:rate_plan, unit_type: unit_type, price_cents: 12_500) }

  before do
    create_list(:unit, 2, unit_type: unit_type, company: user.company, status: 'available')
    sign_in user
  end

  it "keeps existing line items available to the Stimulus controller after a validation error" do
    order = user.company.orders.new(
      customer: customer,
      location: location,
      start_date: Date.today,
      end_date: Date.today + 7.days,
      status: 'draft',
      created_by: user
    )

    Orders::Builder.new(order).assign(
      params: {
        customer_id: customer.id,
        location_id: location.id,
        start_date: order.start_date,
        end_date: order.end_date,
        status: 'draft'
      },
      unit_type_requests: [
        { unit_type_id: unit_type.id, rate_plan_id: rate_plan.id, quantity: 1 }
      ]
    )
    order.save!

    patch order_path(order), params: {
      order: {
        customer_id: customer.id,
        location_id: location.id,
        start_date: "", # trigger builder validation error
        end_date: order.end_date,
        status: 'draft',
        unit_type_requests: {
          "0" => {
            unit_type_id: unit_type.id,
            rate_plan_id: rate_plan.id,
            quantity: 1
          }
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)

    doc = Nokogiri::HTML.parse(response.body)
    widget = doc.at_css('[data-controller="order-items"]')
    expect(widget).to be_present

    existing_payload = widget['data-order-items-existing-value']
    parsed = JSON.parse(existing_payload)

    expect(parsed).to include(
      a_hash_including(
        "unit_type_id" => unit_type.id,
        "rate_plan_id" => rate_plan.id,
        "quantity" => 1
      )
    )
  end
end
