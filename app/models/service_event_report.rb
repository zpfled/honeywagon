# ServiceEventReport stores submitted field data for service or pickup events.
class ServiceEventReport < ApplicationRecord
  belongs_to :service_event
  belongs_to :user

  before_validation :inherit_user_from_event, if: -> { user_id.blank? && service_event.present? }

  validates :data, presence: true

  private

  def inherit_user_from_event
    self.user = service_event.user
  end
end
