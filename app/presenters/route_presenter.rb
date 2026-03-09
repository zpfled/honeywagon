class RoutePresenter
  def initialize(route)
    @route = route
  end

  def display_name
    towns = ordered_events.filter_map { |event| town_for_event(event) }
    deduped_towns = towns.each_with_object([]) { |town, memo| memo << town unless memo.include?(town) }
    return deduped_towns.join(" -> ") if deduped_towns.any?

    route.truck&.name.presence || "Route #{route.id}"
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

  def ordered_events
    @ordered_events ||= route.ordered_stops_or_events.filter_map do |item|
      item.respond_to?(:service_event) ? item.service_event : item
    end
  end

  def town_for_event(event)
    return nil unless event

    city = event.order&.location&.city.presence || event.dump_site&.location&.city.presence
    city&.strip&.titleize
  end
end
