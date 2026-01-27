# frozen_string_literal: true

module Routes
  class CapacityRoutingPreviewPresenter
    PreviewRoute = Struct.new(
      :index,
      :date,
      :stops,
      :usage,
      :trailer_capacity,
      :waste_capacity,
      :clean_capacity,
      keyword_init: true
    )
    PreviewStop = Struct.new(
      :label,
      :kind_label,
      :tone,
      :location_label,
      :customer_name,
      :scheduled_on,
      :notes,
      :capacity_label,
      :capacity_over,
      keyword_init: true
    )
    PreviewStep = Struct.new(
      :waste_used,
      :clean_used,
      :trailer_used,
      :waste_capacity,
      :clean_capacity,
      :trailer_capacity,
      :violations,
      keyword_init: true
    )

    def initialize(result:, company:)
      @result = result
      @company = company
    end

    def routes
      @routes ||= Array(result.routes).each_with_index.map do |route, idx|
        trailer = select_trailer_for(route.stops)
        truck = preferred_truck
        steps = capacity_steps_for(route.stops, truck: truck, trailer: trailer)
        PreviewRoute.new(
          index: idx + 1,
          date: route.date,
          stops: build_stops(route.stops, steps),
          usage: route_usage(route.stops),
          trailer_capacity: trailer&.capacity_spots,
          waste_capacity: truck&.waste_capacity_gal,
          clean_capacity: truck&.clean_water_capacity_gal
        )
      end
    end

    def horizon_days
      company.routing_horizon_days || 3
    end

    private

    attr_reader :result, :company

    def build_stops(stops, steps)
      Array(stops).each_with_index.map do |stop, idx|
        if stop.is_a?(Hash) && stop[:type] == :dump
          build_dump_stop(stop, steps[idx])
        elsif stop.is_a?(Hash) && stop[:type] == :home_base
          build_home_base_stop(stop, steps[idx])
        else
          build_event_stop(stop, steps[idx])
        end
      end
    end

    def build_home_base_stop(stop, step)
      reason = stop[:reason].to_s.humanize
      label = reason.present? ? "Home base (#{reason})" : 'Return to home base'
      PreviewStop.new(
        label: label,
        kind_label: home_base_kind_label(stop[:reason]),
        tone: home_base_tone(stop[:reason]),
        location_label: stop[:location]&.display_label || 'Home base',
        customer_name: nil,
        scheduled_on: nil,
        notes: stop[:location]&.full_address,
        capacity_label: capacity_label(step),
        capacity_over: step&.violations&.any?
      )
    end

    def build_dump_stop(stop, step)
      dump_site = stop[:dump_site]
      PreviewStop.new(
        label: 'Dump stop',
        kind_label: 'Dump',
        tone: :danger,
        location_label: dump_site&.location&.display_label || stop[:location]&.display_label,
        customer_name: dump_site&.name,
        scheduled_on: nil,
        notes: dump_site&.location&.full_address,
        capacity_label: capacity_label(step),
        capacity_over: step&.violations&.any?
      )
    end

    def build_event_stop(event, step)
      PreviewStop.new(
        label: event.batch_label || event.event_type.to_s.humanize,
        kind_label: event.event_type.to_s.humanize,
        tone: event_tone(event),
        location_label: event.order&.location&.display_label,
        customer_name: event.order&.customer&.display_name,
        scheduled_on: event.scheduled_on,
        notes: units_note(event),
        capacity_label: capacity_label(step),
        capacity_over: step&.violations&.any?
      )
    end

    def units_note(event)
      return nil if event.event_type_dump? || event.event_type_refill?

      count = event.units_impacted_count
      count.positive? ? "#{count} units" : nil
    end

    def capacity_label(step)
      return nil unless step

      [
        capacity_metric('Trailer', step.trailer_used, step.trailer_capacity),
        capacity_metric('Waste', step.waste_used, step.waste_capacity, unit: 'gal'),
        capacity_metric('Clean', step.clean_used, step.clean_capacity, unit: 'gal')
      ].compact.join(' • ')
    end

    def capacity_metric(label, used, capacity, unit: nil)
      used_value = used.to_i
      capacity_value = capacity ? capacity.to_i : '—'
      suffix = unit ? " #{unit}" : ''
      "#{label} #{used_value}/#{capacity_value}#{suffix}"
    end

    def route_usage(stops)
      Array(stops).each_with_object({ trailer_spots: 0, waste_gallons: 0, clean_water_gallons: 0 }) do |stop, memo|
        next if stop.is_a?(Hash) || stop.status_skipped?

        usage = event_usage(stop)
        memo[:trailer_spots] += usage[:trailer_spots].to_i
        memo[:waste_gallons] += usage[:waste_gallons].to_i
        memo[:clean_water_gallons] += usage[:clean_water_gallons].to_i
      end
    end

    def event_usage(event)
      @event_usage ||= {}
      @event_usage[event.id] ||= ServiceEvents::ResourceCalculator.new(event).usage
    end

    def capacity_steps_for(stops, truck:, trailer:)
      waste_capacity = truck&.waste_capacity_gal
      clean_capacity = truck&.clean_water_capacity_gal
      trailer_capacity = trailer&.capacity_spots
      waste_used = truck&.waste_load_gal.to_i
      clean_used = 0
      trailer_used = 0

      Array(stops).map do |stop|
        if stop.is_a?(Hash)
          case stop[:type]
          when :dump
            waste_used = 0
          when :home_base
            clean_used = 0 if stop[:reset_clean]
            trailer_used = 0 if stop[:reset_trailer]
          end
        elsif stop.status_skipped?
          # Skipped events do not consume capacity; record current usage.
        else
          usage = event_usage(stop)
          waste_used += usage[:waste_gallons].to_i
          clean_used += usage[:clean_water_gallons].to_i

          trailer_delta = usage[:trailer_spots].to_i
          if stop.event_type_delivery?
            trailer_used = [ trailer_used - trailer_delta, 0 ].max
          elsif stop.event_type_pickup?
            trailer_used += trailer_delta
          end

        end

        PreviewStep.new(
          waste_used: waste_used,
          clean_used: clean_used,
          trailer_used: trailer_used,
          waste_capacity: waste_capacity,
          clean_capacity: clean_capacity,
          trailer_capacity: trailer_capacity,
          violations: preview_violations(waste_used, clean_used, trailer_used, waste_capacity, clean_capacity, trailer_capacity)
        )
      end
    end

    def preview_violations(waste_used, clean_used, trailer_used, waste_capacity, clean_capacity, trailer_capacity)
      [].tap do |violations|
        violations << :waste if waste_capacity && waste_used > waste_capacity
        violations << :clean if clean_capacity && clean_used > clean_capacity
        violations << :trailer if trailer_capacity && trailer_used > trailer_capacity
      end
    end

    def event_tone(event)
      return :success if event.event_type_delivery?
      return :warning if event.event_type_pickup?
      return :info if event.event_type_service?

      :info
    end

    def home_base_kind_label(reason)
      case reason&.to_sym
      when :reload then 'Reload'
      when :refill then 'Refill'
      else
        'Home base'
      end
    end

    def home_base_tone(reason)
      case reason&.to_sym
      when :reload then :warning
      when :refill then :info
      else
        :info
      end
    end

    def preferred_truck
      @preferred_truck ||= begin
        trucks = company.trucks
        return if trucks.blank?

        trucks.order(Arel.sql('preference_rank IS NULL'), :preference_rank, :waste_capacity_gal).first
      end
    end

    def preferred_trailer
      @preferred_trailer ||= begin
        trailers = company.trailers
        return if trailers.blank?

        trailers.order(:capacity_spots, Arel.sql('preference_rank IS NULL'), :preference_rank).first
      end
    end

    def select_trailer_for(stops)
      trailers = company.trailers
      return if trailers.blank?

      required = Array(stops).filter_map do |stop|
        next if stop.is_a?(Hash)
        next if stop.status_skipped?

        event_usage(stop)[:trailer_spots].to_i
      end.max.to_i

      eligible = trailers.where('capacity_spots >= ?', required)
      scope = eligible.presence || trailers
      scope.order(:capacity_spots, Arel.sql('preference_rank IS NULL'), :preference_rank).first
    end
  end
end
