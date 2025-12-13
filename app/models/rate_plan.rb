# RatePlan stores the billing parameters (price, cadence) for each unit type.
class RatePlan < ApplicationRecord
  SERVICE_SCHEDULES = {
    none:     'none',
    weekly:   'weekly',
    biweekly: 'biweekly',
    event:    'event'
  }.freeze
  BILLING_PERIODS = %w[monthly per_event].freeze

  belongs_to :unit_type

  enum :service_schedule, SERVICE_SCHEDULES, suffix: true

  validates :service_schedule, :billing_period, presence: true
  validates :service_schedule, inclusion: { in: SERVICE_SCHEDULES.values }
  validates :billing_period, inclusion: { in: BILLING_PERIODS }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  # Scope returning rate plans flagged as active.
  scope :active, -> { where(active: true) }


  # Returns a quick label combining billing period, schedule, and price.
  def label
    "#{billing_period}: #{service_schedule} -- #{price_cents}"
  end
end
