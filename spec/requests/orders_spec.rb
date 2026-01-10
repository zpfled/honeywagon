require "rails_helper"

RSpec.describe "/orders", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  describe "authentication" do
    it "redirects guests to the sign-in page" do
      get orders_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "scoped access" do
    before { sign_in user }

    it "lists only the signed-in user's orders" do
      own_order = create(:order, :active, created_by: user, company: user.company)
      other_order = create(:order, company: create(:company), customer: create(:customer, business_name: "Other Co"))

      get orders_path

      expect(response.body).to include(own_order.customer.display_name)
      expect(response.body).not_to include(other_order.customer.display_name)
    end

    it "prevents access to another user's order" do
      other_order = create(:order)

      get order_path(other_order)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "new order form scoping" do
    before { sign_in user }

    it "only lists the current company's unit types in the line item selector" do
      own_type   = create(:unit_type, name: "Own Type", company: user.company)
      other_type = create(:unit_type, name: "Other Type")

      get new_order_path

      expect(response.body).to include(own_type.name)
      expect(response.body).not_to include(other_type.name)
    end

    it "only lists the current company's customers in the customer dropdown" do
      own_customer = create(:customer, business_name: "Own Customer", company: user.company)
      other_customer = create(:customer, business_name: "Other Customer")

      get new_order_path

      expect(response.body).to include(own_customer.display_name)
      expect(response.body).not_to include(other_customer.display_name)
    end

    it "only lists the current company's locations in the location dropdown" do
      own_location = create(:location, label: "Own Site", customer: create(:customer, company: user.company))
      other_location = create(:location, label: "Other Site")

      get new_order_path

      expect(response.body).to include(own_location.display_label)
      expect(response.body).not_to include(other_location.display_label)
    end
  end

  describe "status filters" do
    before { sign_in user }

    around do |example|
      travel_to(Date.new(2026, 1, 15)) { example.run }
    end

    let!(:active_order) do
      customer = create(:customer, company: user.company, business_name: "Active Customer")
      location = create(:location, customer: customer, label: "Active Site")
      create(:order, :active, company: user.company, created_by: user, customer: customer, location: location)
    end

    let!(:completed_order) do
      customer = create(:customer, company: user.company, business_name: "Completed Customer")
      location = create(:location, customer: customer, label: "Completed Site")
      create(:order, :completed, company: user.company, created_by: user, customer: customer, location: location)
    end

    let!(:scheduled_order) do
      customer = create(:customer, company: user.company, business_name: "Scheduled Customer")
      location = create(:location, customer: customer, label: "Scheduled Site")
      create(:order, :scheduled, company: user.company, created_by: user, customer: customer, location: location)
    end

    it "defaults to active when no status filters are provided" do
      get orders_path(month: "2026-01")

      expect(response.body).to include(active_order.customer.display_name)
      expect(response.body).not_to include(completed_order.customer.display_name)
      expect(response.body).not_to include(scheduled_order.customer.display_name)
    end

    it "supports combined status filters" do
      get orders_path(month: "2026-01", status: %w[active completed])

      expect(response.body).to include(active_order.customer.display_name)
      expect(response.body).to include(completed_order.customer.display_name)
      expect(response.body).not_to include(scheduled_order.customer.display_name)
    end

    it "shows all orders when no filters are selected" do
      get orders_path(month: "2026-01", status: [ "" ])

      expect(response.body).to include(active_order.customer.display_name)
      expect(response.body).to include(completed_order.customer.display_name)
      expect(response.body).to include(scheduled_order.customer.display_name)
    end
  end

  describe "rescheduling service events" do
    before { sign_in user }

    it "reschedules scheduled service events using the last completed service event" do
      order = create(:order, :active,
                     company: user.company,
                     created_by: user,
                     start_date: Date.new(2023, 12, 1),
                     end_date: Date.new(2024, 2, 1))
      completed_event = create(:service_event, :service, order: order, status: :completed)
      completed_event.update_column(:completed_on, Date.new(2024, 1, 1))
      future_service = create(:service_event, :service, order: order, scheduled_on: Date.new(2024, 1, 10))
      pickup_event = create(:service_event, :pickup, order: order, scheduled_on: Date.new(2024, 1, 12))

      allow(Orders::ServiceScheduleResolver).to receive(:interval_days).with(order).and_return(14)

      post reschedule_service_events_order_path(order)

      expect(response).to redirect_to(order_path(order))
      expect(future_service.reload.scheduled_on).to eq(Date.new(2024, 1, 15))
      expect(pickup_event.reload.scheduled_on).to eq(Date.new(2024, 1, 12))
    end
  end
end
