module ServiceEvents
  # Calculates clean water gallons required for a service event.
  class CleanGallonsEstimator
    def initialize(event)
      @event = event
    end

    def self.call(event)
      new(event).call
    end

    def call
      case event.event_type.to_sym
      when :delivery
        sum_by_unit_type(:delivery_clean_gallons)
      when :service
        sum_by_unit_type(:service_clean_gallons)
      when :pickup
        sum_by_unit_type(:pickup_clean_gallons)
      else
        0
      end
    end

    private

    attr_reader :event

    def sum_by_unit_type(field)
      event.units_by_type.sum do |unit_type, quantity|
        per_unit = unit_type.public_send(field).to_i
        per_unit * quantity
      end
    end
  end
end
