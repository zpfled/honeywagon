module Dashboard
  # Computes summary stats for dashboard inventory widgets.
  class InventoryMetrics
    def initialize(company:)
      @company = company
    end

    def call
      {
        inventory_stats: inventory_stats,
        ytd_order_total_cents: year_to_date_order_total_cents
      }
    end

    private

    attr_reader :company

    def inventory_stats
      monthly_counts = company.rental_counts_for_period('monthly')
      event_counts = company.rental_counts_for_period('per_event')

      company.unit_types.order(:name).map do |unit_type|
        {
          unit_type: unit_type,
          total_units: company.total_units_count(unit_type),
          available_units: company.units_available_count(unit_type),
          rented_units: company.units_rented_count(unit_type),
          monthly_out: monthly_counts[unit_type.id] || 0,
          event_out: event_counts[unit_type.id] || 0
        }
      end
    end

    def year_to_date_order_total_cents
      start_of_year = Date.current.beginning_of_year
      end_of_year = Date.current.end_of_year

      company.orders
              .where(start_date: start_of_year..end_of_year)
              .sum(:total_cents)
              .to_i
    end
  end
end
