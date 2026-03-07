module Routes
  module Generation
    class DraftRouter
      Result = Struct.new(:run, :routes, :warnings, :errors, keyword_init: true)

      def self.call(company:, scope:, horizon_days:, replace: true, strategy: 'capacity_v1', created_by: nil)
        new(
          company: company,
          scope: scope,
          horizon_days: horizon_days,
          replace: replace,
          strategy: strategy,
          created_by: created_by
        ).call
      end

      def initialize(company:, scope:, horizon_days:, replace:, strategy:, created_by:)
        @company = company
        @scope = scope
        @horizon_days = horizon_days
        @replace = replace
        @strategy = strategy
        @created_by = created_by
      end

      def call
        planning = Routes::CapacityRouting::Planner.call(
          company: company,
          start_date: scope.window_start,
          horizon_days: horizon_days
        )

        run = nil
        routes = []

        ActiveRecord::Base.transaction do
          # Route locking is handled by the active-run state transition.
          run = build_run
          @run = run
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

      attr_reader :company, :scope, :horizon_days, :replace, :strategy, :created_by, :run

      def build_run
        run = RouteGenerationRun.create!(
          company: company,
          created_by: created_by,
          scope_key: scope.scope_key,
          window_start: scope.window_start,
          window_end: scope.window_end,
          strategy: strategy,
          state: RouteGenerationRun::STATE_DRAFT,
          source_params: { horizon_days: horizon_days, strategy: strategy }
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

      def populate_route_stops(route:, stops:)
        position = 0
        stops.each do |stop|
          event = stop.is_a?(ServiceEvent) ? stop : build_operational_event(stop, route: route)
          next unless event

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
    end
  end
end
