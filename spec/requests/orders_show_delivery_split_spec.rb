require "rails_helper"

RSpec.describe "Orders show delivery splitting", type: :request do
  around do |example|
    Routes::ServiceEventRouter.without_auto_assignment { example.run }
  end

  it "shows split delivery batches on the order page" do
    user = create(:user)
    company = user.company
    customer = create(:customer, company: company)
    location = create(:location, customer: customer)
    unit_type = create(:unit_type, :standard, company: company)
    rate_plan = create(:rate_plan, company: company, unit_type: unit_type, service_schedule: RatePlan::SERVICE_SCHEDULES[:none])
    create(:trailer, company: company, capacity_spots: 2, preference_rank: 1)

    order = create(
      :order,
      company: company,
      created_by: user,
      customer: customer,
      location: location,
      status: "draft",
      start_date: Date.new(2024, 8, 1),
      end_date: Date.new(2024, 8, 10)
    )
    create(:rental_line_item, order: order, unit_type: unit_type, rate_plan: rate_plan, service_schedule: RatePlan::SERVICE_SCHEDULES[:none], quantity: 5)

    order.schedule!

    deliveries = order.service_events.where(event_type: :delivery).order(:delivery_batch_sequence)
    expect(deliveries.count).to eq(3)
    expect(deliveries.pluck(:delivery_batch_total).uniq).to eq([ 3 ])

    sign_in user
    get order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Delivery (1/3)")
    expect(response.body).to include("Delivery (2/3)")
    expect(response.body).to include("Delivery (3/3)")
  end
end
