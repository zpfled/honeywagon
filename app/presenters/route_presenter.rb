class RoutePresenter
  def initialize(route)
    @route = route
  end

  def deliveries_count
    service_events.count(&:event_type_delivery?)
  end

  def services_count
    service_events.count(&:event_type_service?)
  end

  def pickups_count
    service_events.count(&:event_type_pickup?)
  end

  def estimated_gallons
    service_events.sum(&:estimated_gallons_pumped)
  end

  # TODO: Add route-level summary helpers (capacity/waste/drive) to thin views.
  def humanized_drive_time
    seconds = route.estimated_drive_seconds.to_i
    return nil unless seconds.positive?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours.positive?
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  def humanized_drive_distance
    meters = route.estimated_drive_meters.to_f
    return nil unless meters.positive?

    miles = meters / 1609.34
    "#{miles.round(1)} mi"
  end

  private

  attr_reader :route

  def service_events
    @service_events ||= route.service_events.to_a
  end
end
