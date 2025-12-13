class ServiceEventType < ApplicationRecord
  has_many :service_events, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: true

  def report_field_keys
    Array(report_fields).map { |field| field['key'] || field[:key] }
  end
end
