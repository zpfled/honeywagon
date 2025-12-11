class Order < ApplicationRecord
  belongs_to :customer
  belongs_to :location

  has_many :order_units, dependent: :destroy
  has_many :units, through: :order_units

  STATUSES = %w[draft scheduled active completed cancelled].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  before_save :recalculate_totals

  STATUSES.each do |status_name|
    define_method("#{status_name}?") { status == status_name }
  end

  scope :upcoming, -> { where("start_date >= ?", Date.today) }
  scope :active_on, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }

  def recalculate_totals
    # Normalize nils to 0 and ensure integers
    self.rental_subtotal_cents = rental_subtotal_cents.to_i
    self.delivery_fee_cents    = delivery_fee_cents.to_i
    self.pickup_fee_cents      = pickup_fee_cents.to_i
    self.discount_cents        = discount_cents.to_i
    self.tax_cents             = tax_cents.to_i

    self.total_cents =
      rental_subtotal_cents +
      delivery_fee_cents +
      pickup_fee_cents -
      discount_cents +
      tax_cents

    self
  end

  def recalculate_totals!
    recalculate_totals
    save!
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end
end
