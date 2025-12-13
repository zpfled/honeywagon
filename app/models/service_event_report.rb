# ServiceEventReport stores submitted field data for service or pickup events.
class ServiceEventReport < ApplicationRecord
  belongs_to :service_event

  validates :data, presence: true
end
