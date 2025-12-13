# Customer represents the billing entity that rents units and owns locations.
class Customer < ApplicationRecord
  has_many :locations, dependent: :destroy

  # Returns a best-effort human name stitched from first/last name fields.
  def full_name
    [ first_name, last_name ].compact.join(' ')
  end

  # Returns the display label used throughout the UI, preferring company name,
  # then personal name, then billing email.
  def display_name
    company_name.presence || full_name.presence || billing_email
  end
end
