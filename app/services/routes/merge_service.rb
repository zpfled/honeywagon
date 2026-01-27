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
        append_events_to_target!
        source.destroy!
      end

      Result.new(success?: true, errors: [])
    rescue StandardError => e
      Result.new(success?: false, errors: [ e.message ])
    end

    private

    attr_reader :source, :target

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
