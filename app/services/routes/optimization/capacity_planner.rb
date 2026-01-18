module Routes
  module Optimization
    # Inserts dump/refill stops as needed so routes can respect truck capacities.
    class CapacityPlanner
      Result = Struct.new(:warnings, :errors, :inserted_event_ids, :ordered_event_ids, keyword_init: true)

      def initialize(route:, ordered_event_ids:)
        @route = route
        @ordered_event_ids = Array(ordered_event_ids)
      end

      def self.call(route:, ordered_event_ids:)
        new(route: route, ordered_event_ids: ordered_event_ids).call
      end

      def call
        cleanup_auto_generated_capacity_stops!

        warnings = []
        inserted_ids = []
        ordered_ids = []

        waste_used = starting_waste
        clean_used = 0
        current_date = nil

        events_in_order.each do |event|
          event_date = event.scheduled_on || route.route_date || Date.current
          if current_date != event_date
            current_date = event_date
            clean_used = 0
          end

          usage = ServiceEvents::ResourceCalculator.new(event).usage

          if clean_capacity && clean_used + usage[:clean_water_gallons].to_i > clean_capacity
            refill_event = create_refill_event(event_date)
            if refill_event
              inserted_ids << refill_event.id
              ordered_ids << refill_event.id
              clean_used = 0
            else
              warnings << 'Clean water capacity exceeded but no home base is configured.'
            end
          end

          if waste_capacity && waste_used + usage[:waste_gallons].to_i > waste_capacity
            dump_event = create_dump_event(event_date)
            if dump_event
              inserted_ids << dump_event.id
              ordered_ids << dump_event.id
              waste_used = 0
            else
              warnings << 'Waste capacity exceeded but no dump site is configured.'
            end
          end

          ordered_ids << event.id

          clean_used += usage[:clean_water_gallons].to_i
          waste_used += usage[:waste_gallons].to_i

          waste_used = 0 if event.event_type_dump?
          clean_used = 0 if event.event_type_refill?

          if clean_capacity && usage[:clean_water_gallons].to_i > clean_capacity
            warnings << "Clean water needs for #{event_label(event)} exceed truck capacity."
          end

          if waste_capacity && usage[:waste_gallons].to_i > waste_capacity
            warnings << "Waste needs for #{event_label(event)} exceed truck capacity."
          end
        end

        Result.new(
          warnings: warnings.uniq,
          errors: [],
          inserted_event_ids: inserted_ids,
          ordered_event_ids: ordered_ids
        )
      end

      private

      attr_reader :route, :ordered_event_ids

      def cleanup_auto_generated_capacity_stops!
        route.service_events
             .where(auto_generated: true, event_type: [ :dump, :refill ], order_id: nil)
             .destroy_all
      end

      def events_in_order
        events_by_id = route.service_events.where(id: ordered_event_ids).index_by(&:id)
        ordered = ordered_event_ids.map { |id| events_by_id[id] }.compact

        remaining = route.service_events.where.not(id: ordered_event_ids)
        ordered + remaining.order(:route_date, :event_type, :created_at)
      end

      def clean_capacity
        route.truck&.clean_water_capacity_gal
      end

      def waste_capacity
        route.truck&.waste_capacity_gal
      end

      def starting_waste
        return 0 unless route.truck_id

        routes = route.company.routes
                      .where(truck_id: route.truck_id)
                      .where('route_date <= ?', route.route_date)
        Routes::WasteTracker.new(routes).starting_loads_by_route_id[route.id].to_i
      end

      def create_dump_event(event_date)
        # TODO: Choose the closest dump site to the previous stop instead of name order.
        dump_site = route.company.dump_sites.order(:name).first
        return nil unless dump_site

        build_event(
          event_type: :dump,
          scheduled_on: event_date,
          route_date: event_date,
          dump_site: dump_site
        )
      end

      def create_refill_event(event_date)
        return nil unless route.company.home_base

        build_event(
          event_type: :refill,
          scheduled_on: event_date,
          route_date: event_date
        )
      end

      def build_event(attrs)
        type = find_or_create_event_type(attrs[:event_type])
        user = route.company.users.first
        return nil unless user

        route.service_events.create!(
          attrs.merge(
            status: :scheduled,
            auto_generated: true,
            user: user,
            service_event_type: type
          )
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn(
          message: 'CapacityPlanner failed to create stop',
          route_id: route.id,
          event_type: attrs[:event_type],
          error_class: e.class.name,
          error_message: e.message
        )
        nil
      end

      def find_or_create_event_type(event_type)
        key = event_type.to_s
        ServiceEventType.find_or_create_by!(key: key) do |type|
          type.name = key.humanize
          type.requires_report = %w[service pickup dump].include?(key)
          type.report_fields = []
        end
      end

      def event_label(event)
        if event.event_type_dump?
          event.dump_site&.name || 'dump event'
        elsif event.event_type_refill?
          'home refill'
        else
          customer_name = event.order&.customer&.display_name || 'customer'
          "#{event.event_type} for #{customer_name}"
        end
      end
    end
  end
end
