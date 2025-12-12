class RatePlan < ApplicationRecord
  SERVICE_SCHEDULES = {
    none:     'none',
    weekly:   'weekly',
    biweekly: 'biweekly',
    event:    'event'
  }.freeze

  belongs_to :unit_type

  enum :service_schedule, SERVICE_SCHEDULES, suffix: true

  validates :service_schedule, :billing_period, presence: true
  validates :service_schedule, inclusion: { in: SERVICE_SCHEDULES.values }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }


  def label
    "#{billing_period}: #{service_schedule} -- #{price_cents}"
  end
end
