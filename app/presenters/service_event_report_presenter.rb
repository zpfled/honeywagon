# frozen_string_literal: true

# TODO: ServiceEventReportPresenter should format log row data (date/time,
# address, gallons/units) and rely on shared formatting helpers.
class ServiceEventReportPresenter
  include FormattingHelper

  def initialize(report)
    @report = report
  end

  def date_label
    format_date(service_event.updated_at.to_date)
  end

  def time_label
    format_time(service_event.updated_at)
  end

  def customer_name
    if dump_event?
      dump_site&.name || 'Dump site'
    else
      order&.customer&.display_name
    end
  end

  def address
    if dump_event?
      dump_site&.location&.full_address || '—'
    else
      [ order&.location&.street, order&.location&.city, order&.location&.state, order&.location&.zip ].compact.join(', ')
    end
  end

  def units_pumped
    return '—' if dump_event?

    report.data['units_pumped'].presence || '—'
  end

  def gallons
    key = dump_event? ? 'estimated_gallons_dumped' : 'estimated_gallons_pumped'
    report.data[key].presence || '—'
  end

  def dump_event?
    service_event.event_type_dump?
  end

  private

  attr_reader :report

  def service_event
    report.service_event
  end

  def order
    service_event.order
  end

  def dump_site
    service_event.dump_site
  end
end
