class ServiceLineItem < ApplicationRecord
  include PriceableLineItem

  belongs_to :order

  SERVICE_SCHEDULES = RatePlan::SERVICE_SCHEDULES.values.freeze

  validates :description, presence: true
  validates :service_schedule, inclusion: { in: SERVICE_SCHEDULES }
  validates :units_serviced, numericality: { greater_than: 0 }

  def service_schedule_label
    service_schedule.to_s.humanize
  end
end
