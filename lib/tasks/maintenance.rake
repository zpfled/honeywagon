# frozen_string_literal: true

namespace :maintenance do
  desc 'Align delivery/pickup service events with routes on the same date'
  task fix_logistics_events: :environment do
    say = ->(msg) { puts "[maintenance] #{msg}" }

    deliveries = ServiceEvent.event_type_delivery.count
    pickups    = ServiceEvent.event_type_pickup.count
    say.call("Scanning #{deliveries} deliveries and #{pickups} pickups…")

    logistics_values = [
      ServiceEvent.event_types[:delivery],
      ServiceEvent.event_types[:pickup]
    ]

    ServiceEvent.where(event_type: logistics_values).find_each do |event|
      next if event.scheduled_on.blank?

      target_date = event.scheduled_on
      next if event.route_date == target_date && event.route&.route_date == target_date

      route = ensure_route_for(event, target_date)
      event.update!(route: route, route_date: target_date)
      say.call("Realigned #{event.event_type} #{event.id} for order #{event.order_id} to #{target_date}")
    rescue StandardError => e
      say.call("Failed to realign event #{event.id}: #{e.message}")
    end

    say.call('Done.')
  end

  def ensure_route_for(event, target_date)
    company = event.order.company
    route = company.routes.find_by(route_date: target_date)
    return route if route

    truck   = event.route&.truck || company.trucks.order(:created_at).first
    trailer = event.route&.trailer

    raise "No trucks available for company #{company.id}" unless truck

    company.routes.create!(route_date: target_date, truck: truck, trailer: trailer)
  end

  desc 'Remove routes that no longer have any service events'
  task prune_empty_routes: :environment do
    say = ->(msg) { puts "[maintenance] #{msg}" }
    total = 0

    Route.includes(:service_events).find_each do |route|
      next unless route.service_events.empty?

      route.destroy
      total += 1
      say.call("Deleted route #{route.id} dated #{route.route_date} (#{route.company&.name || 'unknown company'})")
    end

    say.call("Removed #{total} empty routes.")
  end
end
