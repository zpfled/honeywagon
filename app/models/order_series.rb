# Links a set of related orders that share a repeating schedule.
class OrderSeries < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :orders, dependent: :nullify

  validates :name, presence: true
end
