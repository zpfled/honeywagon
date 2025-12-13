# Company represents a single tenant that owns users, units, and orders.
class Company < ApplicationRecord
  BLOCKING_STATUSES = Order::BLOCKING_STATUSES

  has_many :users, dependent: :destroy
  has_many :unit_types, dependent: :destroy
  has_many :units, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :name, presence: true

  def units_rented_count(unit_type)
    assigned_units_by_type[unit_type.id] || 0
  end

  def units_available_count(unit_type)
    total = total_units_by_type[unit_type.id] || 0
    [ total - units_rented_count(unit_type), 0 ].max
  end

  def total_units_count(unit_type)
    total_units_by_type[unit_type.id] || 0
  end

  def rental_counts_for_period(period)
    rental_counts_by_period[period.to_s] || {}
  end

  private

  def total_units_by_type
    @total_units_by_type ||= units.group(:unit_type_id).count
  end

  def assigned_units_by_type
    @assigned_units_by_type ||= OrderUnit
      .joins(:order, :unit)
      .where(orders: { company_id: id, status: BLOCKING_STATUSES })
      .group('units.unit_type_id')
      .distinct
      .count('order_units.unit_id')
  end

  def rental_counts_by_period
    @rental_counts_by_period ||= begin
      counts = OrderUnit
        .joins(:order, :unit)
        .joins(<<~SQL)
          INNER JOIN order_line_items oli
            ON oli.order_id = order_units.order_id
           AND oli.unit_type_id = units.unit_type_id
        SQL
        .where(orders: { company_id: id, status: BLOCKING_STATUSES })
        .group('oli.billing_period', 'units.unit_type_id')
        .distinct
        .count('order_units.id')

      counts.each_with_object(Hash.new { |h, k| h[k] = {} }) do |((period, unit_type_id), value), memo|
        memo[period][unit_type_id] = value
      end
    end
  end
end
