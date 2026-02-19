module Orders
  class SeriesCreator
    Result = Struct.new(:orders, :series, :errors, keyword_init: true) do
      def success? = errors.blank?
    end

    def initialize(company:, created_by:, base_params:, unit_type_requests:, service_item_requests:, date_pairs:, series_name: nil)
      @company = company
      @created_by = created_by
      @base_params = base_params
      @unit_type_requests = unit_type_requests
      @service_item_requests = service_item_requests
      @date_pairs = date_pairs
      @series_name = series_name
      @errors = []
    end

    def call
      pairs = normalize_pairs
      validate_pairs(pairs)
      return Result.new(orders: [], series: nil, errors: errors) if errors.any?

      orders = []
      series = nil

      ActiveRecord::Base.transaction do
        series = company.order_series.create!(
          name: series_name.presence || default_series_name,
          created_by: created_by
        )

        pairs.each do |pair|
          order = company.orders.new(created_by: created_by, order_series: series)
          order.suppress_recurring_service_events = true
          builder = Orders::Builder.new(order)
          builder.assign(
            params: base_params.merge(start_date: pair[:delivery_on], end_date: pair[:pickup_on]),
            unit_type_requests: unit_type_requests,
            service_item_requests: service_item_requests
          )
          if order.errors.any?
            errors.concat(order.errors.full_messages)
            raise ActiveRecord::Rollback
          end
          order.save!
          orders << order
        end
      end

      Result.new(orders: orders, series: series, errors: errors)
    end

    private

    attr_reader :company, :created_by, :base_params, :unit_type_requests, :service_item_requests, :date_pairs, :series_name, :errors

    def normalize_pairs
      Array(date_pairs).filter_map do |pair|
        delivery = parse_date(pair[:delivery_on])
        pickup = parse_date(pair[:pickup_on])
        next if delivery.blank? && pickup.blank?

        { delivery_on: delivery, pickup_on: pickup }
      end
    end

    def validate_pairs(pairs)
      if pairs.empty?
        errors << 'Add at least one delivery/pickup pair.'
        return
      end

      pairs.each_with_index do |pair, idx|
        if pair[:delivery_on].blank? || pair[:pickup_on].blank?
          errors << "Pair #{idx + 1} must include both delivery and pickup dates."
          next
        end

        if pair[:pickup_on] < pair[:delivery_on]
          errors << "Pair #{idx + 1} pickup date must be on or after delivery date."
        end
      end
    end

    def parse_date(value)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def default_series_name
      customer = base_params[:customer_id] ? Customer.find_by(id: base_params[:customer_id]) : nil
      location = base_params[:location_id] ? Location.find_by(id: base_params[:location_id]) : nil
      parts = []
      parts << customer&.display_name if customer
      parts << location&.display_label if location
      parts << 'Series'
      parts.compact.join(' — ')
    end
  end
end
