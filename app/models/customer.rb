class Customer < ApplicationRecord
  has_many :locations, dependent: :destroy

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  def display_name
    company_name.presence || full_name.presence || billing_email
  end
end
