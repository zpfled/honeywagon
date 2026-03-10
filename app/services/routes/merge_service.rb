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
        append_stops_to_target!
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
      source.ordered_route_stops.includes(:service_event).each do |source_stop|
        event = source_stop.service_event
        next unless event

        source_stop.update!(
          route: target,
          position: sequence,
          status: event.status
        )
        event.update!(scheduled_on: target.route_date)

        sequence += 1
      end
    end

    def start_sequence_for_target
      target.route_stops.maximum(:position).to_i + 1
    end
  end
end
