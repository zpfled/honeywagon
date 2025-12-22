# Expense represents a cost that can be allocated across routes/events.
class Expense < ApplicationRecord
  CATEGORIES = %w[fuel insurance rent supplies labor maintenance other].freeze
  COST_TYPES = %w[fixed_monthly fixed_annual per_event per_unit per_mile per_minute].freeze
  APPLIES_TO_OPTIONS = %w[delivery service pickup dump all].freeze

  belongs_to :company

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :cost_type, inclusion: { in: COST_TYPES }
  validates :base_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :package_size, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }

  def per_unit_cost
    return base_amount if package_size.blank? || package_size.to_f.zero?

    base_amount / package_size
  end

  def applies_to_all?
    applies_to.include?('all') || applies_to.empty?
  end
end
