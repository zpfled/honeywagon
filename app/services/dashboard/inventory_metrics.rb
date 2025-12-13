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
      inventory = company.inventory

      company.unit_types.order(:name).map do |unit_type|
        {
          unit_type: unit_type,
          total_units: inventory.total_units(unit_type: unit_type),
          available_units: inventory.available_count(unit_type: unit_type),
          rented_units: inventory.rented_count(unit_type: unit_type),
          monthly_out: inventory.rental_count_for_period(unit_type: unit_type, billing_period: 'monthly'),
          event_out: inventory.rental_count_for_period(unit_type: unit_type, billing_period: 'per_event')
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
