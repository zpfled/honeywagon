module Routes
  module Generation
    class DraftRouter
      Result = Struct.new(:run, :routes, :warnings, :errors, keyword_init: true)

      def self.call(company:, scope:, horizon_days:, planning_start_date: nil, replace: true, strategy: 'capacity_v1', created_by: nil)
        new(
          company: company,
          scope: scope,
          horizon_days: horizon_days,
          planning_start_date: planning_start_date,
          replace: replace,
          strategy: strategy,
          created_by: created_by
        ).call
      end

      def initialize(company:, scope:, horizon_days:, planning_start_date:, replace:, strategy:, created_by:)
        @company = company
        @scope = scope
        @horizon_days = horizon_days
        @planning_start_date = planning_start_date
        @replace = replace
        @strategy = strategy
        @created_by = created_by
      end

      def call
        previous_active_run = replace ? active_run_for_scope : nil
        planning = Routes::CapacityRouting::Planner.call(
          company: company,
          start_date: planning_window_start,
          horizon_days: horizon_days
        )

        run = nil
        routes = []

        ActiveRecord::Base.transaction do
          # Route locking is handled by the active-run state transition.
          run = build_run
          @run = run
          carry_forward_non_overlapping_routes!(from_run: previous_active_run, to_run: run) if replace

          planning.routes.each do |route_plan|
            next unless route_plan&.stops&.any?

            route = build_route(route_plan)
            routes << route
            populate_route_stops(route: route, stops: route_plan.stops)
          end
          run.mark_active! if run
        end

        Result.new(
          run: run,
          routes: routes,
          warnings: planning.warnings || [],
          errors: planning.errors || []
        )
      rescue StandardError => e
        Result.new(run: run, routes: routes, warnings: [], errors: [ "Route generation failed: #{e.message}" ])
      end

      private

      attr_reader :company, :scope, :horizon_days, :planning_start_date, :replace, :strategy, :created_by, :run

      def build_run
        run = RouteGenerationRun.create!(
          company: company,
          created_by: created_by,
          scope_key: scope.scope_key,
          window_start: scope.window_start,
          window_end: scope.window_end,
          strategy: strategy,
          state: RouteGenerationRun::STATE_DRAFT,
          source_params: {
            horizon_days: horizon_days,
            strategy: strategy,
            planning_start_date: planning_window_start.to_s,
            planning_end_date: planning_window_end.to_s
          }
        )

        supersede_previous_runs(run) if replace
        run
      end

      def supersede_previous_runs(run)
        company.route_generation_runs
               .where(scope_key: run.scope_key)
               .where.not(id: run.id)
               .where(state: :active)
               .update_all(state: RouteGenerationRun::STATE_SUPERSEDED)
      end

      def build_route(route_plan)
        planned_date = route_plan.date.to_date
        Route.without_auto_assignment do
          Route.create!(
            company: company,
            route_date: planned_date,
            truck: company.trucks.order(:created_at).first,
            trailer: choose_trailer(route_plan),
            generation_run: run
          )
        end
      end

      def active_run_for_scope
        company.route_generation_runs
               .where(scope_key: scope.scope_key, state: :active)
               .order(created_at: :desc)
               .first
      end

      def carry_forward_non_overlapping_routes!(from_run:, to_run:)
        return unless from_run

        overlap_range = planning_window_start..planning_window_end
        from_run.routes
                .includes(:route_stops)
                .where.not(route_date: overlap_range)
                .order(:route_date, :id)
                .find_each do |old_route|
          duplicate_route_with_stops!(old_route: old_route, new_run: to_run)
        end
      end

      def duplicate_route_with_stops!(old_route:, new_run:)
        copied_route = old_route.dup
        copied_route.generation_run = new_run
        copied_route.save!

        old_route.route_stops.order(:position).find_each do |stop|
          stop.update!(
            route: copied_route,
            position: stop.position,
            status: stop.status,
            planned_arrival_at: stop.planned_arrival_at,
            planned_departure_at: stop.planned_departure_at,
            created_by: created_by || stop.created_by
          )

          stop.service_event.update_columns(
            route_id: copied_route.id,
            route_date: copied_route.route_date,
            route_sequence: stop.position
          )
        end
      end

      def populate_route_stops(route:, stops:)
        position = 0
        stops.each do |stop|
          event = stop.is_a?(ServiceEvent) ? stop : build_operational_event(stop, route: route)
          next unless event

          existing_stop = RouteStop.find_by(service_event_id: event.id)
          if existing_stop
            existing_stop.update!(
              route: route,
              position: position,
              status: event.status
            )
            event.update_columns(
              route_id: route.id,
              route_sequence: position,
              route_date: route.route_date
            )
          else
            event.update_columns(
              route_id: route.id,
              route_sequence: position,
              route_date: route.route_date
            )
            event.reload

            route.append_service_event_stop!(
              event,
              position: position,
              created_by: created_by
            )
          end
          position += 1
        end
      end

      def build_operational_event(stop, route:)
        event_type = normalize_operational_type(stop)
        return if event_type == :none

        type = ServiceEventType.find_by!(key: event_type.to_s)
        attrs = {
          service_event_type: type,
          route: route,
          route_date: route.route_date,
          scheduled_on: route.route_date,
          auto_generated: true,
          user: created_by || company.users.first,
          status: :scheduled
        }.compact

        return ServiceEvent.create!(attrs.merge(event_type: :dump, dump_site: stop[:dump_site])) if event_type == :dump

        ServiceEvent.create!(attrs.merge(event_type: :refill))
      end

      def normalize_operational_type(stop)
        return :none unless stop.is_a?(Hash)

        type = stop[:type].to_s
        return :dump if type == 'dump'
        return :refill if [ 'home_base', 'refill' ].include?(type)

        :none
      end

      def choose_trailer(route_plan)
        required_spots = minimum_trailer_spots(route_plan.stops)
        trailers = company.trailers.order(:capacity_spots)
        return nil unless trailers.exists?

        trailers.find { |trailer| trailer.capacity_spots >= required_spots } || trailers.last
      end

      def minimum_trailer_spots(stops)
        return 0 if stops.blank?

        stops.select { |stop| stop.is_a?(ServiceEvent) }.sum do |event|
          ServiceEvents::ResourceCalculator.new(event).usage[:trailer_spots].to_i
        end
      end

      def planning_window_start
        (planning_start_date || scope.window_start).to_date
      end

      def planning_window_end
        planning_window_start + (horizon_days - 1).days
      end
    end
  end
end
