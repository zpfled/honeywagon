module ServiceEvents
  # Calculates estimated waste gallons for a service event.
  class GallonsEstimator
    DEFAULT_SERVICE_WASTE_GALLONS = 10

    def initialize(event)
      @event = event
    end

    def self.call(event)
      new(event).call
    end

    def call
      return event.estimated_gallons_override if event.estimated_gallons_override.present?
      return 0 if event.event_type_delivery? || event.event_type_dump? || event.event_type_refill?
      return 0 unless event.order

      total_units = rental_units_waste
      total_units += service_line_units * DEFAULT_SERVICE_WASTE_GALLONS if event.event_type_service?
      total_units
    end

    private

    attr_reader :event

    def rental_units_waste
      field = event.event_type_pickup? ? :pickup_waste_gallons : :service_waste_gallons
      event.order.rental_line_items.includes(:unit_type).sum do |item|
        unit_type = item.unit_type
        next 0 unless unit_type
        unit_type.public_send(field).to_i * item.quantity.to_i
      end
    end

    def service_line_units
      event.order.service_line_items.sum(:units_serviced)
    end
  end
end
