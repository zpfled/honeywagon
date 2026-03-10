# frozen_string_literal: true

module Routes
  module Planning
    class PersistPlan
      Result = Struct.new(:routes, keyword_init: true)

      CompletedEventAssignmentError = Class.new(StandardError)

      def self.call(company:, route_plans:, actor: nil)
        new(company: company, route_plans: route_plans, actor: actor).call
      end

      def initialize(company:, route_plans:, actor:)
        @company = company
        @route_plans = Array(route_plans)
        @actor = actor
      end

      def call
        routes = []

        route_plans.each do |route_plan|
          next unless route_plan&.stops&.any?

          route = build_route(route_plan)
          routes << route
          persist_stops!(route: route, stops: route_plan.stops)
        end

        Result.new(routes: routes)
      end

      private

      attr_reader :company, :route_plans, :actor

      def build_route(route_plan)
        Route.without_auto_assignment do
          Route.create!(
            company: company,
            route_date: route_plan.date.to_date,
            truck: company.trucks.order(:created_at).first,
            trailer: choose_trailer(route_plan)
          )
        end
      end

      def persist_stops!(route:, stops:)
        position = 0
        stops.each do |raw_stop|
          event = raw_stop.is_a?(ServiceEvent) ? raw_stop : build_operational_event(raw_stop, route: route)
          next unless event

          raise CompletedEventAssignmentError, completed_assignment_message(event) if event.status_completed?

          existing_stop = RouteStop.find_by(service_event_id: event.id)
          if existing_stop
            existing_stop.update!(
              route: route,
              position: position,
              status: event.status,
              created_by: actor || existing_stop.created_by
            )
          else
            route.route_stops.create!(
              service_event: event,
              position: position,
              status: event.status,
              created_by: actor
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
          scheduled_on: route.route_date,
          auto_generated: true,
          user: actor || company.users.first,
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

      def completed_assignment_message(event)
        "Cannot assign completed service event #{event.id} to a new route."
      end
    end
  end
end
