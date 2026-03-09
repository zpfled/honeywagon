class RoutesController < ApplicationController
  before_action :set_route, only: %i[update push_to_calendar merge]
  before_action :set_route_with_service_events, only: %i[show]
  before_action :load_fleet_assets, only: %i[show update]
  helper_method :run_label

  def show
    load_route_details
  end

  def calendar
    @calendar_start = calendar_start_date
    @calendar_end = @calendar_start + 27.days
    @calendar_strategy = calendar_strategy
    company = current_user.company
    Weather::ForecastRefresher.call(company: company)
    @scope = Routes::Generation::Scope.new(
      company: company,
      scope_start: @calendar_start,
      scope_end: @calendar_end,
      strategy: @calendar_strategy
    )

    resolver = Routes::Generation::RunResolver.call(
      company: company,
      scope: @scope,
      run_id: params[:run_id]
    )
    @generation_run = resolver.run
    @generation_runs = company.route_generation_runs
                              .where(scope_key: @scope.scope_key)
                              .order(created_at: :desc)

    if @generation_run
      @run_routes = @generation_run.routes
                                    .includes(:truck, :trailer, :route_stops, :stop_service_events)
                                    .where(route_date: @calendar_start..@calendar_end)
                                    .order(:route_date, :id)
      @routes_by_date = @run_routes.group_by(&:route_date)
      @run_stops = RouteStop
                   .where(route_id: @run_routes.map(&:id))
                   .joins(:service_event)
                   .where(service_events: { event_type: due_event_types })
                   .includes(:service_event)
                   .to_a
    else
      @run_routes = []
      @routes_by_date = {}
      @run_stops = []
    end

    @due_events = company.service_events
                         .scheduled
                         .where(event_type: due_event_types)
                         .where(scheduled_on: @calendar_start..@calendar_end)
                         .includes(:dump_site, :route_stops, order: :customer)
    @due_events_by_date = @due_events.group_by(&:scheduled_on)
    assigned_event_ids = assigned_event_ids_in_run(run: @generation_run, event_ids: @due_events.map(&:id))
    @assigned_due_events_by_date = @due_events.select { |event| assigned_event_ids.include?(event.id) }
                                              .group_by(&:scheduled_on)
    @unassigned_events = @due_events.reject { |event| assigned_event_ids.include?(event.id) }
    @unassigned_events_by_date = @unassigned_events.group_by(&:scheduled_on)
    @forecast_by_date = calendar_forecasts(company)
    @plan_window_start, @plan_window_end = selected_planning_window
  end

  def day
    @date = route_day_date
    company = current_user.company
    scope_start = @date.beginning_of_week(:sunday)
    scope_end = scope_start + 27.days
    @calendar_strategy = calendar_strategy

    @scope = Routes::Generation::Scope.new(
      company: company,
      scope_start: scope_start,
      scope_end: scope_end,
      strategy: @calendar_strategy
    )
    @generation_run = Routes::Generation::RunResolver.call(
      company: company,
      scope: @scope,
      run_id: params[:run_id],
      allow_cross_scope_run_id: true
    ).run

    @due_events = company.service_events
                         .scheduled
                         .where(event_type: due_event_types)
                         .where(scheduled_on: @date)
                         .includes(:order, :dump_site, :route_stops)
                         .order(:scheduled_on, :created_at)

    @assigned_stops = if @generation_run
                        RouteStop.joins(:route)
                                 .joins(:service_event)
                                 .where(service_events: { event_type: due_event_types })
                                 .where(routes: { generation_run_id: @generation_run.id, route_date: @date })
                                 .includes(:route, :service_event)
                                 .order('route_stops.route_id ASC, route_stops.position ASC')
    else
                        []
    end

    assigned_event_ids = assigned_event_ids_in_run(run: @generation_run, event_ids: @due_events.map(&:id))
    @unassigned_events = @due_events.reject { |event| assigned_event_ids.include?(event.id) }

    @tasks = company.tasks.where(due_on: @date).order(:created_at)
  end

  def clear_day
    date = route_day_date
    company = current_user.company
    scope_start = date.beginning_of_week(:sunday)
    scope_end = scope_start + 27.days
    scope = Routes::Generation::Scope.new(
      company: company,
      scope_start: scope_start,
      scope_end: scope_end,
      strategy: calendar_strategy
    )
    run = Routes::Generation::RunResolver.call(
      company: company,
      scope: scope,
      run_id: params[:run_id],
      allow_cross_scope_run_id: true
    ).run

    unless run
      return redirect_to(day_routes_path(date: date, strategy: calendar_strategy), alert: 'No active run available for this date.')
    end

    result = Routes::DayRouteClearer.new(run: run, date: date).call
    if result.success?
      message = "Cleared #{result.routes_cleared} route#{'s' if result.routes_cleared != 1} and released #{result.events_released} event#{'s' if result.events_released != 1}."
      redirect_to day_routes_path(date: date, run_id: run.id, strategy: calendar_strategy), notice: message
    else
      redirect_to day_routes_path(date: date, run_id: run.id, strategy: calendar_strategy), alert: result.error
    end
  end

  def reschedule_service_event
    service_event = current_user.company.service_events.scheduled.find(params[:service_event_id])
    target_date = Date.parse(params[:target_date].to_s)
    move_scope = params[:move_scope].to_s == 'future' ? :future : :single

    if move_scope == :future && !series_eligible_service_event?(service_event)
      return render json: { status: 'error', message: 'This event is not part of a recurring series.' }, status: :unprocessable_content
    end

    if service_event.prevent_move_later? && target_date > service_event.scheduled_on
      return render json: { status: 'error', message: 'Deliveries cannot move later.' }, status: :unprocessable_content
    end

    if service_event.prevent_move_earlier? && target_date < service_event.scheduled_on
      return render json: { status: 'error', message: 'Pickups cannot move earlier.' }, status: :unprocessable_content
    end

    moved_count = if move_scope == :future
                    reschedule_series_from_anchor!(service_event: service_event, target_date: target_date)
    else
                    ActiveRecord::Base.transaction do
                      detach_event_from_route!(service_event)
                      service_event.update!(
                        scheduled_on: target_date,
                        route: nil,
                        route_date: target_date,
                        route_sequence: nil
                      )
                    end
                    1
    end

    render json: {
      status: 'ok',
      service_event_id: service_event.id,
      target_date: target_date.to_s,
      moved_count: moved_count
    }
  rescue ActiveRecord::RecordNotFound
    render json: { status: 'error', message: 'Service event not found.' }, status: :not_found
  rescue ArgumentError
    render json: { status: 'error', message: 'Invalid date.' }, status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { status: 'error', message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def generate
    plan_start, plan_end = selected_planning_window
    horizon = ((plan_end - plan_start).to_i + 1).clamp(1, 28)
    scope = Routes::Generation::Scope.new(
      company: current_user.company,
      scope_start: calendar_start_date,
      scope_end: calendar_start_date + 27.days,
      strategy: calendar_strategy
    )
    result = Routes::Generation::DraftRouter.call(
      company: current_user.company,
      scope: scope,
      horizon_days: horizon,
      planning_start_date: plan_start,
      replace: params[:replace] != 'false',
      strategy: scope.strategy,
      created_by: current_user
    )

    if result.run
      route_count = result.routes.size
      start_date = plan_start
      end_date = plan_end
      due_count = current_user.company.service_events
                              .scheduled
                              .where(event_type: due_event_types)
                              .where(scheduled_on: start_date..end_date)
                              .count
      assigned_count = RouteStop.joins(:route)
                                .joins(:service_event)
                                .where(routes: { generation_run_id: result.run.id, route_date: start_date..end_date })
                                .where(service_events: { event_type: due_event_types })
                                .count
      unassigned_count = [ due_count - assigned_count, 0 ].max
      candidate_count = Routes::CapacityRouting::CandidatePool
                        .new(
                          company: current_user.company,
                          start_date: start_date,
                          horizon_days: ((end_date - start_date).to_i + 1)
                        )
                        .events
                        .size
      range_label = "#{I18n.l(start_date, format: '%b %-d')}–#{I18n.l(end_date, format: '%b %-d')}"
      if route_count.zero? && due_count.positive?
        base_message = "No routes generated for #{range_label}. #{due_count} due event#{'s' if due_count != 1}, #{candidate_count} eligible candidate#{'s' if candidate_count != 1}, #{unassigned_count} unassigned."
        if result.errors.present?
          flash[:alert] = "#{base_message} Error: #{Array(result.errors).join(', ')}"
        else
          flash[:alert] = base_message
        end
      else
        flash[:notice] = "#{route_count} route#{'s' if route_count != 1} generated for #{range_label}. #{unassigned_count} event#{'s' if unassigned_count != 1} unassigned."
      end
      redirect_to calendar_routes_path(
        start: scope.window_start,
        run_id: result.run.id,
        plan_start: plan_start,
        plan_end: plan_end,
        strategy: scope.strategy
      )
    else
      message = "Could not generate routes: #{result.errors.join(', ')}"
      redirect_to calendar_routes_path(start: scope.window_start), alert: message
    end
  end

  def create
    @route = current_user.company.routes.new(route_params)

    if @route.save
      redirect_to @route, notice: 'Route created.'
    else
      redirect_back fallback_location: authenticated_root_path,
                    alert: @route.errors.full_messages.to_sentence
    end
  end

  def update
    #   @route_summary, @dump_sites, @stop_presenters
    if @route.update(route_params)
      redirect_to @route, notice: 'Route updated.'
    else
      load_route_details
      render :show, status: :unprocessable_content
    end
  end

  def push_to_calendar
    result = Routes::GoogleCalendarPusher.new(route: @route, user: current_user).call

    if result.success?
      redirect_to @route, notice: 'Route pushed to Google Calendar.'
    else
      redirect_to @route, alert: result.errors.to_sentence
    end
  end

  def refresh_forecasts
    Weather::ForecastRefreshJob.perform_later(current_user.company_id)
    redirect_to calendar_routes_path, notice: 'Forecast refresh queued.'
  end

  def merge
    target = current_user.company.routes.find(params[:target_id])
    result = Routes::MergeService.call(source: @route, target: target)

    if result.success?
      render json: { status: 'ok' }
    else
      render json: { status: 'error', errors: result.errors }, status: :unprocessable_content
    end
  end

  private

  def due_event_types
    [ ServiceEvent.event_types[:delivery], ServiceEvent.event_types[:service], ServiceEvent.event_types[:pickup] ]
  end

  def set_route
    @route = current_user.company.routes.find(params[:id])
  end

  def set_route_with_service_events
    @route = current_user.company.routes
                               .includes(:route_stops, :service_events)
                               .find(params[:id])
  end

  def load_route_details
    presenter = Routes::DetailPresenter.new(@route, company: current_user.company)
    @service_events = presenter.service_events
    @stop_presenters = presenter.stop_presenters
    @map_stops = presenter.map_stops
    @previous_route = presenter.previous_route
    @next_route = presenter.next_route
    @waste_load = presenter.waste_load
    @capacity_steps = presenter.capacity_steps
    @dump_sites = current_user.company.dump_sites.includes(:location)
    @weather_forecast = presenter.weather_forecast
    @route_summary = Routes::ShowSummaryPresenter.new(route: @route, waste_load: @waste_load)
    @route_header = Routes::ShowHeaderPresenter.new(
      route: @route,
      previous_route: @previous_route,
      next_route: @next_route,
      weather_forecast: @weather_forecast,
      view_context: view_context
    )
  end

  def load_fleet_assets
    company = current_user.company
    @trucks = company.trucks.order(:name, :number)
    @trailers = company.trailers.order(:name, :identifier)
  end

  def route_params
    params.require(:route).permit(:route_date, :truck_id, :trailer_id)
  end

  def calendar_start_date
    seed = params[:start].presence
    return Date.parse(seed).beginning_of_week(:sunday) if seed

    (Date.current.beginning_of_week(:sunday) - 7.days)
  rescue ArgumentError
    (Date.current.beginning_of_week(:sunday) - 7.days)
  end

  def route_day_date
    seed = params[:date].presence
    parsed = seed ? Date.parse(seed) : Date.current
    parsed
  rescue ArgumentError
    Date.current
  end

  def calendar_strategy
    params[:strategy].presence || 'capacity_v1'
  end

  def selected_planning_window
    raw_start = params[:plan_start].presence
    raw_end = params[:plan_end].presence

    start_date = raw_start ? Date.parse(raw_start) : Date.current
    end_date = raw_end ? Date.parse(raw_end) : (start_date + 2.days)
    end_date = start_date if end_date < start_date

    [ start_date, end_date ]
  rescue ArgumentError
    [ Date.current, Date.current + 2.days ]
  end

  def run_label(run)
    return 'Run' unless run

    created_at = run.created_at
    created_label = created_at ? I18n.l(created_at, format: :short) : 'n/a'
    state = run.state || 'draft'

    "#{state.titleize} · #{created_label} · #{run.strategy}"
  end

  def assigned_event_ids_in_run(run:, event_ids:)
    return Set.new if run.blank? || event_ids.blank?

    RouteStop.joins(:route)
             .where(routes: { generation_run_id: run.id })
             .where(service_event_id: event_ids)
             .distinct
             .pluck(:service_event_id)
             .to_set
  end

  def series_eligible_service_event?(service_event)
    service_event.event_type_service? && service_event.order_id.present?
  end

  def recurring_series_future_events_for(service_event)
    current_user.company.service_events
                .scheduled
                .where(
                  order_id: service_event.order_id,
                  event_type: ServiceEvent.event_types[:service]
                )
                .where(ServiceEvent.arel_table[:scheduled_on].gteq(service_event.scheduled_on))
                .order(:scheduled_on, :id)
                .to_a
  end

  def reschedule_series_from_anchor!(service_event:, target_date:)
    order = service_event.order
    interval_days = order ? Orders::ServiceScheduleResolver.interval_days(order) : nil
    unless interval_days.present?
      service_event.errors.add(:base, 'Missing recurring service interval.')
      raise ActiveRecord::RecordInvalid.new(service_event)
    end

    moved = 0
    future_events = recurring_series_future_events_for(service_event)

    ActiveRecord::Base.transaction do
      detach_event_from_route!(service_event)
      service_event.update!(
        scheduled_on: target_date,
        route: nil,
        route_date: target_date,
        route_sequence: nil
      )
      moved += 1

      next_date = target_date
      future_events.reject { |event| event.id == service_event.id }.each do |event|
        next_date += interval_days
        detach_event_from_route!(event)

        if order.end_date.present? && next_date > order.end_date
          event.destroy!
        else
          event.update!(
            scheduled_on: next_date,
            route: nil,
            route_date: next_date,
            route_sequence: nil
          )
        end
        moved += 1
      end
    end

    moved
  end

  def detach_event_from_route!(event)
    source_route = event.route
    source_stop = if source_route&.has_stop_projection?
                    source_route.route_stops.find_by(service_event_id: event.id)
    end
    source_stop&.destroy!
    source_route&.synchronize_route_sequence_with_stops! if source_route&.has_stop_projection?
  end

  def calendar_forecasts(company)
    location = company.home_base
    return {} unless location&.lat.present? && location&.lng.present?

    lat = location.lat.to_f.round(4)
    lng = location.lng.to_f.round(4)
    today = Date.current
    forecasts = {}

    provider = company.weather_provider.presence || 'nws'
    past_logs = ForecastLog
                .where(company: company, provider: provider, latitude: lat, longitude: lng)
                .where(forecast_date: @calendar_start..@calendar_end)
                .where('forecast_date < ?', today)
                .where.not(observed_high_temp: nil, observed_low_temp: nil)

    past_logs.each do |log|
      forecasts[log.forecast_date] = Struct.new(:high_temp, :low_temp, :precip_percent).new(
        high_temp: log.observed_high_temp,
        low_temp: log.observed_low_temp,
        precip_percent: log.predicted_precip_percent
      )
    end

    horizon = Weather::ForecastFetcher.forecast_horizon(company)
    @calendar_start.upto(@calendar_end) do |date|
      next if date < today || date > today + horizon

      forecast = Weather::ForecastFetcher.call(
        company: company,
        date: date,
        latitude: lat,
        longitude: lng
      )
      forecasts[date] = forecast if forecast.present?
    end

    forecasts
  end
end
