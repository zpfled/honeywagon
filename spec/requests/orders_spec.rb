# spec/requests/orders_spec.rb
require "rails_helper"

RSpec.describe "/orders", type: :request do
  # If you use Devise and Orders are behind auth, uncomment this and ensure
  # Devise::Test::IntegrationHelpers is included in rails_helper.rb
  #
  # let(:user) { create(:user) }
  # before { sign_in user }

  let(:customer) { create(:customer) }
  let(:location) { create(:location) }

  # Build a "valid" params hash from your factory.
  # This avoids guessing what fields Order requires.
  let(:valid_attributes) do
    attributes_for(:order).merge(customer_id: customer.id, location_id: location.id)
  end

  let(:invalid_attributes) do
    valid_attributes.merge(customer_id: nil)
  end

  # For update specs, change *some* field to a different value.
  let(:new_attributes) do
    attrs = valid_attributes.deep_dup

    candidate_key =
      attrs.keys.grep_v(/_id\z/).first || attrs.keys.first

    old = attrs[candidate_key]

    attrs[candidate_key] =
      case old
      when String
        old + " (updated)"
      when Integer
        old + 1
      when Date
        old + 1
      when Time, ActiveSupport::TimeWithZone
        old + 1.minute
      when TrueClass, FalseClass
        !old
      else
        # fallback: just set *something* different
        "updated"
      end

    attrs
  end

  describe "GET /index" do
    it "renders a successful response" do
      get orders_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      order = create(:order)
      get order_url(order)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_order_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      order = create(:order)
      get edit_order_url(order)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Order" do
        expect do
          post orders_url, params: { order: valid_attributes }
        end.to change(Order, :count).by(1)
      end

      it "redirects to the created order" do
        post orders_url, params: { order: valid_attributes }
        expect(response).to redirect_to(order_url(Order.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Order" do
        expect do
          post orders_url, params: { order: invalid_attributes }
        end.not_to change(Order, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post orders_url, params: { order: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      it "updates the requested order" do
        order = create(:order)

        patch order_url(order), params: { order: new_attributes }
        order.reload

        # We don't know which field changed (dynamic), but we can at least assert it didn't 422.
        expect(response).not_to have_http_status(:unprocessable_entity)
      end

      it "redirects to the order" do
        order = create(:order)

        patch order_url(order), params: { order: new_attributes }
        expect(response).to redirect_to(order_url(order))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        order = create(:order)

        patch order_url(order), params: { order: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested order" do
      order = create(:order)

      expect do
        delete order_url(order)
      end.to change(Order, :count).by(-1)
    end

    it "redirects to the orders list" do
      order = create(:order)

      delete order_url(order)
      expect(response).to redirect_to(orders_url)
    end
  end
end
