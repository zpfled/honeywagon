module Orders
  class AvailabilityPresenter
    def initialize(summary)
      @summary = summary
    end

    def to_h
      { availability: availability_entries }
    end

    private

    attr_reader :summary

    def availability_entries
      summary.summary.map do |entry|
        unit_type = entry[:unit_type]
        {
          unit_type_id: unit_type.id,
          name: unit_type.name,
          available: entry[:available]
        }
      end
    end
  end
end
