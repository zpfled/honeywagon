# Company represents a single tenant that owns users, units, and orders.
class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :unit_types, dependent: :destroy
  has_many :units, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :name, presence: true

  def inventory
    Company::Inventory.new(company: self)
  end
end
