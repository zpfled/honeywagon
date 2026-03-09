module Routes
  module CapacityRouting
    # Collects events within the routing horizon and normalizes their constraints.
    class CandidatePool
      def initialize(company:, start_date:, horizon_days:)
        @company = company
        @start_date = start_date
        @horizon_days = horizon_days
      end

      def events
        scheduled_events.map { |event| Candidate.new(event: event) }
      end

      private

      attr_reader :company, :start_date, :horizon_days

      def scheduled_events
        horizon_end = start_date + horizon_days.days
        ServiceEvent
          .scheduled
          .where(event_type: %i[delivery service pickup])
          .where(scheduled_on: start_date..horizon_end)
          .joins(:order)
          .where(orders: { company_id: company.id, status: Order::BLOCKING_STATUSES })
          .includes(order: :location, service_event_units: :unit_type)
      end

      # Wraps a ServiceEvent with constraint metadata for routing decisions.
      class Candidate
        attr_reader :event

        def initialize(event:)
          @event = event
        end

        def due_date
          event.scheduled_on
        end

        def delivery?
          event.event_type_delivery?
        end

        def pickup?
          event.event_type_pickup?
        end

        def service?
          event.event_type_service?
        end

        def location
          event.order&.location
        end
      end
    end
  end
end
