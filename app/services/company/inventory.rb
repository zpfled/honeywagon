class Company::Inventory
  # Provides reusable inventory/availability metrics scoped to a tenant.
  BLOCKING_STATUSES = Order::BLOCKING_STATUSES

  attr_reader :company

  def initialize(company:)
    @company = company
  end

  # Returns total units owned for the given unit type.
  def total_units(unit_type:)
    total_units_by_type[unit_type.id] || 0
  end

  # Returns how many units of this type are assigned to blocking orders overlapping the window.
  def rented_count(unit_type:, start_date: Date.current, end_date: Date.current, statuses: BLOCKING_STATUSES)
    rented_units_for_window(start_date: start_date, end_date: end_date, statuses: statuses)[unit_type.id] || 0
  end

  # Returns how many units could be assigned within the provided window.
  def available_count(unit_type:, start_date: Date.current, end_date: Date.current, statuses: BLOCKING_STATUSES)
    [ total_units(unit_type: unit_type) -
      rented_count(unit_type: unit_type, start_date: start_date, end_date: end_date, statuses: statuses), 0 ].max
  end

  # Counts units out on the provided billing period (e.g., monthly or per_event).
  def rental_count_for_period(unit_type:, billing_period:, start_date: Date.current, end_date: Date.current, statuses: BLOCKING_STATUSES)
    rental_counts_by_period(start_date: start_date, end_date: end_date, statuses: statuses)[billing_period.to_s][unit_type.id] || 0
  end

  private

  def rented_units_for_window(start_date:, end_date:, statuses:)
    cached_window_query(:rented_units, start_date, end_date, statuses) do
      OrderUnit
        .joins(:order, :unit)
        .where(orders: { company_id: company.id, status: statuses })
        .where('orders.start_date <= ? AND orders.end_date >= ?', end_date, start_date)
        .group('units.unit_type_id')
        .distinct
        .count('order_units.unit_id')
    end
  end

  def total_units_by_type
    @total_units_by_type ||= company.units.group(:unit_type_id).count
  end

  def rental_counts_by_period(start_date:, end_date:, statuses:)
    cached_window_query(:rental_counts_by_period, start_date, end_date, statuses) do
      counts = OrderUnit
               .joins(:order, :unit)
               .where(orders: { company_id: company.id, status: statuses })
               .where('orders.start_date <= ? AND orders.end_date >= ?', end_date, start_date)
               .group('order_units.billing_period', 'units.unit_type_id')
               .distinct
               .count('order_units.unit_id')

      counts.each_with_object(Hash.new { |h, k| h[k] = {} }) do |((period, unit_type_id), value), memo|
        memo[period][unit_type_id] = value
      end
    end
  end

  def cached_window_query(name, start_date, end_date, statuses)
    @window_cache ||= Hash.new { |h, k| h[k] = {} }
    cache_key = [ start_date, end_date, Array(statuses).sort ].hash
    cache = @window_cache[name]
    cache[cache_key] ||= yield
  end
end
