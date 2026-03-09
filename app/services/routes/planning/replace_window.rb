# frozen_string_literal: true

require 'digest'

module Routes
  module Planning
    class ReplaceWindow
      Result = Struct.new(
        :success?,
        :routes,
        :warnings,
        :errors,
        :replaced_routes_count,
        :window_start,
        :window_end,
        :code,
        keyword_init: true
      )

      CompletedStopsLockedError = Class.new(StandardError)

      def self.call(company:, start_date:, end_date:, actor: nil)
        new(company: company, start_date: start_date, end_date: end_date, actor: actor).call
      end

      def initialize(company:, start_date:, end_date:, actor:)
        @company = company
        @window_start = start_date.to_date
        @window_end = end_date.to_date
        @actor = actor
      end

      def call
        return invalid_window_result if window_end < window_start
        return missing_truck_result unless company.trucks.exists?

        routes = []
        warnings = []
        replaced_routes_count = 0

        ActiveRecord::Base.transaction do
          acquire_window_lock!

          existing_routes = company.routes.where(route_date: window_start..window_end).lock('FOR UPDATE').to_a
          raise CompletedStopsLockedError, completed_lock_message(existing_routes) if completed_stops_in?(existing_routes)

          planning = Routes::CapacityRouting::Planner.call(
            company: company,
            start_date: window_start,
            horizon_days: horizon_days
          )

          replaced_routes_count = existing_routes.size
          existing_routes.each(&:destroy!)

          persist_result = PersistPlan.call(
            company: company,
            route_plans: planning.routes,
            actor: actor
          )
          routes = persist_result.routes
          warnings = planning.warnings || []
        end

        Result.new(
          success?: true,
          routes: routes,
          warnings: warnings,
          errors: [],
          replaced_routes_count: replaced_routes_count,
          window_start: window_start,
          window_end: window_end,
          code: :ok
        )
      rescue CompletedStopsLockedError => e
        Result.new(
          success?: false,
          routes: [],
          warnings: [],
          errors: [ e.message ],
          replaced_routes_count: 0,
          window_start: window_start,
          window_end: window_end,
          code: :completed_events_locked
        )
      rescue StandardError => e
        Result.new(
          success?: false,
          routes: [],
          warnings: [],
          errors: [ "Route planning failed: #{e.message}" ],
          replaced_routes_count: 0,
          window_start: window_start,
          window_end: window_end,
          code: :planning_failed
        )
      end

      private

      attr_reader :company, :window_start, :window_end, :actor

      def horizon_days
        ((window_end - window_start).to_i + 1).clamp(1, 28)
      end

      def acquire_window_lock!
        key = advisory_lock_key
        ActiveRecord::Base.connection.select_value("SELECT pg_advisory_xact_lock(#{key})")
      end

      def advisory_lock_key
        raw = "routes:replace_window:#{company.id}:#{window_start.iso8601}:#{window_end.iso8601}"
        Digest::SHA256.hexdigest(raw).first(15).to_i(16)
      end

      def completed_stops_in?(routes)
        return false if routes.empty?

        RouteStop.joins(:service_event)
                 .where(route_id: routes.map(&:id))
                 .where(service_events: { status: ServiceEvent.statuses[:completed] })
                 .exists?
      end

      def completed_lock_message(routes)
        route_labels = routes.map { |route| "#{route.id} (#{route.route_date})" }
        "Cannot replace routes in #{window_start}..#{window_end}. Completed events exist on: #{route_labels.join(', ')}"
      end

      def invalid_window_result
        Result.new(
          success?: false,
          routes: [],
          warnings: [],
          errors: [ 'Invalid planning window: end date must be on or after start date.' ],
          replaced_routes_count: 0,
          window_start: window_start,
          window_end: window_end,
          code: :invalid_window
        )
      end

      def missing_truck_result
        Result.new(
          success?: false,
          routes: [],
          warnings: [],
          errors: [ 'Cannot plan routes without at least one truck.' ],
          replaced_routes_count: 0,
          window_start: window_start,
          window_end: window_end,
          code: :missing_truck
        )
      end
    end
  end
end
