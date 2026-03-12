module ServiceEvents
  # Calculates estimated waste gallons for a service event.
  class WasteGallonsEstimator
    DEFAULT_SERVICE_WASTE_GALLONS = 10 # Default gallons per serviced unit.

    def initialize(event)
      @event = event # Event being evaluated.
    end

    def self.call(event)
      new(event).call # Convenience class-level entrypoint.
    end

    def call
      return event.estimated_gallons_override if event.estimated_gallons_override.present? # Manual override wins.
      return 0 if no_waste_pumped?
      return 0 unless event.order # Can't estimate without an order.

      total_gallons_waste = rental_units_waste # Start with waste from rental units.
      total_gallons_waste += private_service_units_waste  # Add service-line waste for service events.
      total_gallons_waste
    end

    private

    attr_reader :event

    def no_waste_pumped?
      event.event_type_delivery? || event.event_type_dump? || event.event_type_refill? # No waste produced.
    end

    def rental_units_waste
      field = event.event_type_pickup? ? :pickup_waste_gallons : :service_waste_gallons # Choose per-unit field by event type.
      event.order.rental_line_items.includes(:unit_type).sum do |item|
        unit_type = item.unit_type
        next 0 unless unit_type # Skip items missing a unit type.
        unit_type.public_send(field).to_i * item.quantity.to_i # Multiply per-unit gallons by quantity.
      end
    end

    def private_service_units_waste
      return 0 unless event.event_type_service?

      service_line_units = event.order.service_line_items.sum(:units_serviced) # Total serviced units on the order.
      service_line_units * DEFAULT_SERVICE_WASTE_GALLONS
    end
  end
end
