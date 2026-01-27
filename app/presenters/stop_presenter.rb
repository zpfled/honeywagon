# frozen_string_literal: true

class StopPresenter
  include FormattingHelper

  def initialize(service_event, capacity_step: nil)
    @service_event = service_event
    @capacity_step = capacity_step
  end

  def id = service_event.id
  def event = service_event

  def stop_number
    service_event.route_sequence.present? ? service_event.route_sequence + 1 : '—'
  end

  def leg_distance
    service_event.humanized_leg_drive_distance
  end

  def fuel_cost
    cents = service_event.estimated_fuel_cost_cents
    cents ? format_money(cents) : nil
  end

  def scheduled_on
    service_event.scheduled_on
  end

  def scheduled_on_long
    scheduled_on
  end

  def event_type
    service_event.event_type
  end

  def event_type_label
    service_event.batch_label || service_event.event_type.to_s.humanize
  end

  def overdue?
    service_event.overdue?
  end

  def days_overdue
    service_event.days_overdue
  end

  def units_impacted
    service_event.event_type_dump? || service_event.event_type_refill? ? '—' : service_event.units_impacted_count
  end

  def refill?
    service_event.event_type_refill?
  end

  def order
    service_event.order
  end

  def order_customer_name
    order&.customer&.display_name
  end

  def order_customer_email
    order&.customer&.billing_email
  end

  def order_location_label
    order&.location&.label
  end

  def order_city_state
    location = order&.location
    [ location&.city, location&.state ].compact.join(', ')
  end

  def order_date_range
    return nil unless order
    start_date = order.start_date
    end_date = order.end_date
    [ start_date, end_date ].all? ? "#{I18n.l(start_date)} → #{I18n.l(end_date)}" : nil
  end

  def dump_site
    service_event.dump_site if service_event.event_type_dump?
  end

  def dump_site_name
    dump_site&.name || 'Dump stop'
  end

  def dump_site_location_label
    dump_site&.location&.display_label || 'Location pending'
  end

  def dump_site_address
    dump_site&.location&.full_address
  end

  def refill_location
    service_event.route&.company&.home_base
  end

  def refill_location_label
    refill_location&.display_label || 'Home base'
  end

  def refill_address
    refill_location&.full_address
  end

  def capacity_step
    capacity_step_data
  end

  def capacity_usage_rows
    return [] unless capacity_step

    rows = []
    rows << usage_row('Waste', capacity_step.waste_used, capacity_step.waste_capacity) if capacity_step.respond_to?(:waste_capacity)
    rows << usage_row('Clean', capacity_step.clean_used, capacity_step.clean_capacity) if capacity_step.respond_to?(:clean_capacity)
    rows << usage_row('Trailer', capacity_step.trailer_used, capacity_step.trailer_capacity) if capacity_step.respond_to?(:trailer_capacity)
    rows.compact
  end

  def capacity_violations
    Array(capacity_step&.violations).map { |v| v[:message] }
  end

  def completed?
    service_event.status_completed?
  end

  def skipped?
    service_event.status_skipped?
  end

  def skip_reason
    service_event.skip_reason
  end

  def delivery?
    service_event.event_type_delivery?
  end

  def dump?
    service_event.event_type_dump?
  end

  def service?
    service_event.event_type_service?
  end

  def disable_move_later?
    completed? || skipped? || service_event.prevent_move_later?
  end

  def disable_move_earlier?
    completed? || skipped? || service_event.prevent_move_earlier?
  end

  def later_hint
    return unless service_event.prevent_move_later?
    'Deliveries must stay on or before their scheduled date.'
  end

  def earlier_hint
    return unless service_event.prevent_move_earlier?
    'Pickups must stay on their scheduled date.'
  end

  def row_classes
    base = 'hover:bg-gray-50'
    return "#{base} opacity-60 bg-emerald-50" if completed?
    return "#{base} opacity-70 bg-amber-50" if skipped?

    base
  end

  private

  attr_reader :service_event, :capacity_step

  def capacity_step_data
    capacity_step
  end

  def usage_row(label, used, capacity)
    return nil unless capacity
    ratio = capacity.zero? ? 0 : (used.to_f / capacity)
    css_class =
      if ratio >= 1
        'text-rose-700 font-semibold'
      elsif ratio >= 0.8
        'text-amber-600 font-semibold'
      else
        'text-gray-600'
      end
    { label: "#{label} #{used}/#{capacity}", css_class: css_class }
  end
end
