class UnitType < ApplicationRecord
  has_many :units, dependent: :nullify

  TYPES = [
    { name: "Standard Unit", slug: "standard" },
    { name: "ADA Accessible Unit", slug: "ada" },
    { name: "Handwash Station", slug: "handwash" }
  ].freeze

  validates :prefix, presence: true, format: { with: /\A[A-Z]\z/ }

  def to_s = name
end
