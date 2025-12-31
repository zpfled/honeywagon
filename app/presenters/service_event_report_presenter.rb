class ServiceEventReportPresenter
  def initialize(report, view_context:)
    @report = report
    @view = view_context
  end

  def date_label
    view.l(central_time.to_date, format: :long)
  rescue StandardError
    central_time.to_date.to_s
  end

  def time_label
    central_time.strftime('%I:%M %p')
  end

  def customer_name
    if dump_event?
      dump_site&.name || 'Dump site'
    else
      order&.customer&.display_name
    end
  end

  def address_label
    if dump_event?
      dump_site&.location&.full_address || '—'
    else
      [ order&.location&.street, order&.location&.city, order&.location&.state, order&.location&.zip ]
        .compact
        .join(', ')
        .presence || '—'
    end
  end

  def units_serviced_label
    return '—' if dump_event?

    report.data['units_pumped'].presence || '—'
  end

  def estimated_gallons_label
    key = dump_event? ? 'estimated_gallons_dumped' : 'estimated_gallons_pumped'
    report.data[key].presence || '—'
  end

  def report
    @report
  end

  private

  attr_reader :view

  def event
    report.service_event
  end

  def order
    event&.order
  end

  def dump_site
    event&.dump_site
  end

  def dump_event?
    event&.event_type_dump?
  end

  def central_time
    event.updated_at.in_time_zone('Central Time (US & Canada)')
  end
end
