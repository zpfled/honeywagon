class UnitType < ApplicationRecord
  has_many :units, dependent: :nullify

  def to_s = name
end
