# RatePlan stores the billing parameters (price, cadence) for each unit type.
class RatePlan < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  SERVICE_SCHEDULES = {
    none:     'none',
    weekly:   'weekly',
    biweekly: 'biweekly',
    monthly:  'monthly',
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


  # Returns a human-friendly label combining schedule, billing period, and price.
  def display_label
    schedule_label = service_schedule.to_s.humanize.presence || 'Service schedule'
    billing_label = billing_period.to_s.humanize.presence || 'Billing period'
    price = number_to_currency(price_cents.to_i / 100.0)
    "#{schedule_label} (#{billing_label}) • #{price}"
  end
end
