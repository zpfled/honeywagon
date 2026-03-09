module Routes
  class MergeService
    Result = Struct.new(:success?, :errors, keyword_init: true)

    def self.call(source:, target:)
      new(source: source, target: target).call
    end

    def initialize(source:, target:)
      @source = source
      @target = target
    end

    def call
      return Result.new(success?: false, errors: [ 'Route merge requires two different routes.' ]) if source.id == target.id

      ActiveRecord::Base.transaction do
        if source.has_stop_projection? || target.has_stop_projection?
          append_stops_to_target!
        else
          append_events_to_target!
        end
        source.destroy!
      end

      Result.new(success?: true, errors: [])
    rescue StandardError => e
      Result.new(success?: false, errors: [ e.message ])
    end

    private

    attr_reader :source, :target

    def append_stops_to_target!
      sequence = start_sequence_for_target
      source.ordered_service_events.each do |event|
        source_stop = source.route_stops.find_by(service_event_id: event.id)

        event.update!(
          route: target,
          route_date: target.route_date,
          scheduled_on: target.route_date,
          route_sequence: sequence
        )

        if target.has_stop_projection?
          if source_stop
            source_stop.update!(
              route: target,
              position: sequence,
              status: event.status
            )
          else
            target.append_service_event_stop!(event, position: sequence)
          end
        end

        sequence += 1
      end
    end

    def start_sequence_for_target
      if target.has_stop_projection?
        target.route_stops.where(route_id: target.id).maximum(:position).to_i + 1
      else
        target.service_events.maximum(:route_sequence).to_i + 1
      end
    end

    def append_events_to_target!
      sequence = target.service_events.maximum(:route_sequence).to_i
      source.service_events.order(:route_sequence, :created_at).find_each do |event|
        sequence += 1
        event.update!(
          route_id: target.id,
          route_date: target.route_date,
          route_sequence: sequence
        )
      end
    end
  end
end
