module ServiceEventsHelper
  # Returns a color-coded badge describing how urgent a service event is.
  def service_event_status_badge(event)
    today = Date.current

    if event.scheduled_on < today
      badge('Overdue', tone: :danger)
    elsif event.scheduled_on <= today + 1.day
      badge('Due soon', tone: :warning)
    end
  end
end
