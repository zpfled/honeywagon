class RatePlan < ApplicationRecord
  belongs_to :unit_type

  validates :service_schedule, :billing_period, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }


  def label
    "#{billing_period}: #{service_schedule} -- #{price_cents}"
  end
end
