class OrderUnit < ApplicationRecord
  belongs_to :order
  belongs_to :unit

  validates :placed_on, presence: true
  validate  :removed_on_after_placed_on, if: -> { removed_on.present? }

  # how many days this unit is on this order (for pricing later)
  def rental_days
    return 0 if placed_on.blank?

    (effective_removed_on - placed_on).to_i + 1
  end

  private

  def effective_removed_on
    removed_on || order&.end_date || placed_on
  end

  def removed_on_after_placed_on
    if removed_on < placed_on
      errors.add(:removed_on, "must be on or after placed_on")
    end
  end
end
