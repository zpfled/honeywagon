require "rails_helper"

RSpec.describe Customer, type: :model do
  describe "#full_name" do
    it "joins first and last name with a space" do
      customer = Customer.new(first_name: "John", last_name: "Doe")

      expect(customer.full_name).to eq("John Doe")
    end

    it "returns just first name when last name is missing" do
      customer = Customer.new(first_name: "John", last_name: nil)

      expect(customer.full_name).to eq("John")
    end

    it "returns an empty string when both names are missing" do
      customer = Customer.new(first_name: nil, last_name: nil)

      expect(customer.full_name).to eq("")
    end
  end

  describe "#computed_display_name" do
    it "prefers business_name when present" do
      customer = Customer.new(
        first_name: "John",
        last_name: "Doe",
        business_name: "Acme Construction",
        billing_email: "john@example.com"
      )

      expect(customer.computed_display_name).to eq("Acme Construction")
    end

    it "falls back to full_name when no business_name" do
      customer = Customer.new(
        first_name: "John",
        last_name: "Doe",
        business_name: nil,
        billing_email: "john@example.com"
      )

      expect(customer.computed_display_name).to eq("John Doe")
    end

    it "falls back to billing_email when no names present" do
      customer = Customer.new(
        first_name: nil,
        last_name: nil,
        business_name: nil,
        billing_email: "no-name@example.com"
      )

      expect(customer.computed_display_name).to eq("no-name@example.com")
    end
  end

  describe "callbacks" do
    it "populates display_name before validation" do
      customer = Customer.new(
        first_name: "Jane",
        last_name: "Smith",
        business_name: nil,
        billing_email: "jane@example.com"
      )

      customer.valid?

      expect(customer.display_name).to eq("Jane Smith")
    end

    it "updates display_name when an attribute changes" do
      customer = create(:customer, business_name: "Acme")

      customer.update!(business_name: nil, first_name: "Mary", last_name: "Major")

      expect(customer.display_name).to eq("Mary Major")
    end
  end
end
