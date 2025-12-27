# frozen_string_literal: true

# TODO: StopPresenter should format per-stop details (leg distance, fuel cost,
# customer/address, usage) to keep views free of model/presentation logic.
class StopPresenter
  include FormattingHelper

  def initialize(service_event, capacity_step: nil)
    @service_event = service_event
    @capacity_step = capacity_step
  end

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

  def event_type
    service_event.event_type
  end

  def overdue?
    service_event.overdue?
  end

  def days_overdue
    service_event.days_overdue
  end

  def units_impacted
    service_event.event_type_dump? ? '—' : service_event.units_impacted_count
  end

  def order
    service_event.order
  end

  def dump_site
    service_event.dump_site if service_event.event_type_dump?
  end

  def capacity_step
    capacity_step_data
  end

  private

  attr_reader :service_event, :capacity_step

  def capacity_step_data
    capacity_step
  end
end
