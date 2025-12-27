# frozen_string_literal: true

# TODO: Move common formatting (money, dates/times) here to reuse across presenters/views.
# This helper can be split into narrower concerns later.
# TODO: Add specs for nil/zero/time-zone edge cases once presenters adopt these helpers.
module FormattingHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TranslationHelper

  DEFAULT_TIME_ZONE = 'Central Time (US & Canada)'.freeze

  # Format cents as currency (e.g., $12.34).
  def format_money(cents)
    return nil unless cents

    number_to_currency(cents.to_f / 100.0)
  end

  # Format a date; defaults to month/day/year with abbreviated month.
  def format_date(date, format: :long)
    return nil unless date

    base_date = date.respond_to?(:to_date) ? date.to_date : date
    return base_date.strftime('%b %-d, %Y') if format == :long

    l(base_date, format: format)
  end

  # Format a time in Central Time by default, hh:mm AM/PM.
  def format_time(time, zone: DEFAULT_TIME_ZONE, strftime: '%I:%M %p')
    return nil unless time

    time.in_time_zone(zone).strftime(strftime)
  end

  # Format a date+time in Central Time, with customizable formats.
  def format_datetime(time, zone: DEFAULT_TIME_ZONE, date_format: :long, time_format: '%I:%M %p')
    return nil unless time

    zoned = time.in_time_zone(zone)
    "#{format_date(zoned.to_date, format: date_format).sub('-', ' ')} #{zoned.strftime(time_format)}"
  end
end
