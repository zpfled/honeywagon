# Customer represents the billing entity that rents units and owns locations.
class Customer < ApplicationRecord
  belongs_to :company
  has_many :locations, dependent: :destroy

  before_validation :refresh_display_name

  validates :display_name, presence: true

  # Returns a best-effort human name stitched from first/last name fields.
  def full_name
    [ first_name, last_name ].compact.join(' ')
  end

  # Returns the derived label used throughout the UI, preferring company name,
  # then personal name, then billing email.
  def computed_display_name
    business_name.presence || full_name.presence || billing_email
  end

  private

  def refresh_display_name
    self.display_name = computed_display_name
  end
end
