module Dashboard
  # Computes summary stats for dashboard inventory widgets.
  class InventoryMetrics
    BLOCKING_STATUSES = %w[scheduled active].freeze

    def call
      {
        inventory_stats: inventory_stats,
        ytd_order_total_cents: year_to_date_order_total_cents
      }
    end

    private

    def inventory_stats
      unit_types = UnitType.order(:name)
      totals = Unit.group(:unit_type_id).count
      status_counts = Unit.group(:unit_type_id, :status).count
      monthly_counts = rental_counts_by_period('monthly')
      event_counts = rental_counts_by_period('per_event')

      unit_types.map do |unit_type|
        {
          unit_type: unit_type,
          total_units: totals[unit_type.id] || 0,
          available_units: status_counts[[ unit_type.id, 'available' ]] || 0,
          rented_units: status_counts[[ unit_type.id, 'rented' ]] || 0,
          monthly_out: monthly_counts[unit_type.id] || 0,
          event_out: event_counts[unit_type.id] || 0
        }
      end
    end

    def rental_counts_by_period(billing_period)
      OrderUnit
        .joins(:order, :unit)
        .joins(<<~SQL)
          INNER JOIN order_line_items oli
            ON oli.order_id = order_units.order_id
           AND oli.unit_type_id = units.unit_type_id
        SQL
        .where(orders: { status: BLOCKING_STATUSES })
        .where(oli: { billing_period: billing_period })
        .group('units.unit_type_id')
        .distinct
        .count('order_units.id')
    end

    def year_to_date_order_total_cents
      start_of_year = Date.current.beginning_of_year
      end_of_year = Date.current.end_of_year

      Order
        .where(start_date: start_of_year..end_of_year)
        .sum(:total_cents)
        .to_i
    end
  end
end
