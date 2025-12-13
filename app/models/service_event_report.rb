class ServiceEventReport < ApplicationRecord
  belongs_to :service_event

  validates :data, presence: true
end
