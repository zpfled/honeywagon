module Orders
  # ServiceEventGenerator builds the system-generated lifecycle events (delivery,
  # recurring service, pickup) for a given order. Replace-all strategy: delete any
  # previously auto-generated events for the order, then rebuild them so rerunning
  # the generator stays idempotent.
  class ServiceEventGenerator
    # Stores the order whose lifecycle events should be regenerated.
    def initialize(order, from_date: nil)
      @order = order
      @from_date = from_date
    end

    # Builds the required service events for the order, replacing existing
    # auto-generated rows so the method remains idempotent.
    def call
      return if order.start_date.blank? || order.end_date.blank?

      order.with_lock do
        delete_scope = order.service_events.auto_generated
        delete_scope = delete_scope.where(ServiceEvent.arel_table[:scheduled_on].gteq(from_date)) if from_date
        delete_scope.delete_all

        build_events.each do |attrs|
          next if from_date && attrs[:scheduled_on] < from_date

          unit_counts = attrs.delete(:units_by_type)
          type = find_or_create_event_type(attrs[:event_type])
          assigned_user = order.created_by || order.company&.users&.first
          raise "Order #{order.id} is missing a user to own generated events" unless assigned_user
          event = order.service_events.create!(
            attrs.merge(
              status: :scheduled,
              auto_generated: true,
              service_event_type: type,
              user: assigned_user
            )
          )
          if unit_counts.present?
            unit_counts.each do |unit_type, quantity|
              next if quantity.to_i <= 0
              event.service_event_units.create!(unit_type: unit_type, quantity: quantity)
            end
          end
        end
      end
    end

    private

    attr_reader :order, :from_date

    # Returns the full ordered list of event attribute hashes that should exist.
    def build_events
      (mandatory_events + recurring_service_events).sort_by { |attrs| attrs[:scheduled_on] }
    end

    # Delivery/pickup events are always present, regardless of schedule.
    def mandatory_events
      delivery_events + pickup_events
    end

    # Returns recurring service events based on the order's effective schedule.
    def recurring_service_events
      interval_days = recurring_interval_days
      return [] unless interval_days

      events = []
      current_date = order.start_date + interval_days

      while current_date < order.end_date
        # Skip dates that collide with delivery or pickup; we don't want duplicate
        # events for the same day.
        unless [ order.start_date, order.end_date ].include?(current_date)
          events << { event_type: :service, scheduled_on: current_date }
        end
        current_date += interval_days
      end

      events
    end

    def delivery_events
      batches = delivery_batches
      total = batches.size
      batches.each_with_index.map do |batch, index|
        {
          event_type: :delivery,
          scheduled_on: order.start_date,
          delivery_batch_sequence: index + 1,
          delivery_batch_total: total,
          units_by_type: batch
        }
      end
    end

    def pickup_events
      batches = pickup_batches
      total = batches.size
      batches.each_with_index.map do |batch, index|
        {
          event_type: :pickup,
          scheduled_on: order.end_date,
          pickup_batch_sequence: index + 1,
          pickup_batch_total: total,
          units_by_type: batch
        }
      end
    end

    def delivery_batches
      units_by_type = order_units_by_type
      return [ units_by_type ] if units_by_type.blank?

      capacity = preferred_trailer_capacity
      return [ units_by_type ] if capacity.to_i <= 0

      total_spots = ServiceEvents::ResourceCalculator.trailer_spots_for(units_by_type)
      return [ units_by_type ] if total_spots <= capacity

      batches = [ Hash.new(0) ]
      sorted_units = units_by_type.sort_by { |unit_type, _| -unit_spot_weight(unit_type) }

      sorted_units.each do |unit_type, quantity|
        quantity.to_i.times do
          placed = false

          batches.each do |batch|
            candidate = batch.merge(unit_type => batch[unit_type].to_i + 1)
            if ServiceEvents::ResourceCalculator.trailer_spots_for(candidate) <= capacity
              batch[unit_type] = candidate[unit_type]
              placed = true
              break
            end
          end

          unless placed
            batches << Hash.new(0)
            batches.last[unit_type] = 1
          end
        end
      end

      batches
    end

    def pickup_batches
      units_by_type = order_units_by_type
      return [ units_by_type ] if units_by_type.blank?

      capacities = trailer_capacities
      return [ units_by_type ] if capacities.blank?

      remaining = units_by_type.each_with_object(Hash.new(0)) do |(unit_type, quantity), memo|
        memo[unit_type] = quantity.to_i
      end

      batches = []
      loop do
        total_spots = ServiceEvents::ResourceCalculator.trailer_spots_for(remaining)
        break if total_spots <= 0

        capacity = capacity_for_remaining(total_spots, capacities)
        batch = build_batch_for_capacity(remaining, capacity)
        break if batch.values.sum <= 0

        batches << batch
        subtract_units!(remaining, batch)
      end

      batches
    end

    def order_units_by_type
      order.rental_line_items.includes(:unit_type).each_with_object(Hash.new(0)) do |item, memo|
        unit_type = item.unit_type
        next unless unit_type
        memo[unit_type] += item.quantity.to_i
      end
    end

    def preferred_trailer_capacity
      trailers = order.company&.trailers
      return nil if trailers.blank?

      required_spots = ServiceEvents::ResourceCalculator.trailer_spots_for(order_units_by_type)

      preferred = trailers
                  .where('capacity_spots >= ?', required_spots)
                  .order(Arel.sql('preference_rank IS NULL'), :preference_rank, :capacity_spots)
                  .first

      fallback = trailers.order(capacity_spots: :desc).first

      (preferred || fallback)&.capacity_spots.to_i
    end

    def trailer_capacities
      order.company&.trailers&.where('capacity_spots > 0')&.order(:capacity_spots)&.pluck(:capacity_spots) || []
    end

    def capacity_for_remaining(total_spots, capacities)
      max = capacities.max
      return capacities.first if max && total_spots > max

      capacities.find { |capacity| capacity >= total_spots } || max
    end

    def build_batch_for_capacity(remaining_units, capacity)
      batch = Hash.new(0)
      sorted_units = remaining_units.sort_by { |unit_type, _| -unit_spot_weight(unit_type) }

      sorted_units.each do |unit_type, quantity|
        quantity.to_i.times do
          candidate = batch.merge(unit_type => batch[unit_type].to_i + 1)
          if ServiceEvents::ResourceCalculator.trailer_spots_for(candidate) <= capacity
            batch[unit_type] = candidate[unit_type]
          end
        end
      end

      batch
    end

    def subtract_units!(remaining_units, batch)
      batch.each do |unit_type, quantity|
        remaining_units[unit_type] = remaining_units[unit_type].to_i - quantity.to_i
        remaining_units.delete(unit_type) if remaining_units[unit_type].to_i <= 0
      end
    end

    def unit_spot_weight(unit_type)
      case unit_type.slug
      when 'ada' then 2
      else
        1
      end
    end

    # Maps the effective schedule string to a recurrence interval in days.
    def recurring_interval_days
      Orders::ServiceScheduleResolver.interval_days(order)
    end

    # Derives the service schedule from rental or service-only line items.
    def effective_service_schedule
      Orders::ServiceScheduleResolver.schedule_for(order)
    end

    # Ensures a ServiceEventType exists for the provided enum symbol.
    def find_or_create_event_type(event_type_symbol)
      key = event_type_symbol.to_s
      ServiceEventType.find_or_create_by!(key: key) do |type|
        type.name = key.humanize
        type.requires_report = %w[service pickup].include?(key)
        type.report_fields = []
      end
    end
  end
end
