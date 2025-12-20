module ServiceEvents
  # Calculates estimated septage gallons for a service event.
  class GallonsEstimator
    def initialize(event)
      @event = event
    end

    def self.call(event)
      new(event).call
    end

    def call
      return event.estimated_gallons_override if event.estimated_gallons_override.present?
      return 0 if event.event_type_delivery? || event.event_type_dump?
      return 0 unless event.order

      total_units = rental_standard_units
      total_units += service_line_units if event.event_type_service?
      total_units * 10
    end

    private

    attr_reader :event

    def rental_standard_units
      event.order.rental_line_items
           .joins(:unit_type)
           .where(unit_types: { slug: %w[standard ada] })
           .sum(:quantity)
    end

    def service_line_units
      event.order.service_line_items.sum(:units_serviced)
    end
  end
end
