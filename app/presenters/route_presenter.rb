class RoutePresenter
  def initialize(route)
    @route = route
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
end
