class ServiceEventReportsController < ApplicationController
  before_action :set_service_event, only: [ :new, :create ]
  before_action :set_report, only: [ :edit, :update ]

  def index
    @month = selected_month
    @previous_month = (@month - 1.month).beginning_of_month
    @next_month = (@month + 1.month).beginning_of_month
    month_start = @month.beginning_of_month
    month_end = @month.end_of_month
    dump_type = ServiceEvent.event_types[:dump]

    month_scope = current_user.service_event_reports
                              .joins(:service_event)
                              .where(service_events: { completed_on: month_start..month_end })
    pumped_sql = "COALESCE((service_event_reports.data->>'estimated_gallons_pumped')::int, 0)"
    dumped_sql = "COALESCE((service_event_reports.data->>'estimated_gallons_dumped')::int, 0)"

    @monthly_pumped_gallons = month_scope.where.not(service_events: { event_type: dump_type }).sum(Arel.sql(pumped_sql)).to_i
    @monthly_dumped_gallons = month_scope.where(service_events: { event_type: dump_type }).sum(Arel.sql(dumped_sql)).to_i

    include_dump_site = month_scope.where(service_events: { event_type: dump_type }).exists?
    event_includes = { order: %i[customer location] }
    event_includes[:dump_site] = :location if include_dump_site

    base_scope = month_scope
                 .includes(service_event: event_includes)
                 .where("service_events.event_type = :dump OR #{pumped_sql} > 0", dump: dump_type)

    @reports = base_scope
               .order(Arel.sql('service_events.completed_on DESC NULLS LAST, service_event_reports.created_at DESC'))
    @report_presenters = @reports.map do |report|
      ServiceEventReportPresenter.new(report, view_context: view_context)
    end
  end

  def new
    # TODO: Changes needed:
    # - Keep prefill/fields building in presenter/service if it grows.
    unless @service_event.report_required?
      redirect_to authenticated_root_path, alert: 'This service event does not require a report.'
      return
    end

    @report = @service_event.service_event_report || @service_event.build_service_event_report(data: {})
    @report_fields = Array(@service_event.service_event_type&.report_fields)
    @prefill = default_prefill_data
    render layout: false if turbo_frame_request?
  end

  def create
    @prefill = default_prefill_data
    report = @service_event.service_event_report || @service_event.build_service_event_report(data: {})
    report.user ||= current_user
    report.data = report.data.merge(report_params.merge(
      'customer_name' => @prefill[:customer_name],
      'customer_address' => @prefill[:customer_address]
    ).compact)

    ServiceEvent.transaction do
      report.save!
      apply_estimated_gallons_override(report)
      @service_event.update!(status: :completed)
    end

    redirect_target = params[:redirect_path].presence ||
                      (@service_event.route ? route_path(@service_event.route) : authenticated_root_path)
    redirect_to redirect_target, notice: 'Service event reported and completed.'
  rescue ActiveRecord::RecordInvalid => e
    @report = report
    @report_fields = Array(@service_event.service_event_type&.report_fields)
    @prefill = default_prefill_data
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    if turbo_frame_request?
      render :new, status: :unprocessable_content, layout: false
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    # TODO: Changes needed:
    # - Keep prefill/fields building in presenter/service if it grows.
    @service_event = @report.service_event
    @report_fields = Array(@service_event.service_event_type&.report_fields)
    @prefill = default_prefill_data
    render layout: false if turbo_frame_request?
  end

  def update
    @service_event = @report.service_event
    @prefill = default_prefill_data
    data = @report.data.merge(report_params.compact)

    if @report.update(data: data)
      apply_estimated_gallons_override(@report)
      redirect_to(params[:redirect_path].presence || service_event_reports_path, notice: 'Service report updated.')
    else
      flash.now[:alert] = @report.errors.full_messages.to_sentence
      if turbo_frame_request?
        render :edit, status: :unprocessable_content, layout: false
      else
        render :edit, status: :unprocessable_content
      end
    end
  end

  private

  def set_service_event
    service_event_id = params.permit(:service_event_id).require(:service_event_id)
    @service_event = current_user.service_events.includes(order: [ :customer, :location ]).find(service_event_id)
  end

  def set_report
    @report = current_user.service_event_reports.includes(service_event: [ { order: %i[customer location] } ]).find(params[:id])
  end

  def report_params
    permitted = params.fetch(:service_event_report, {}).permit(:estimated_gallons_pumped, :units_pumped, :estimated_gallons_dumped).to_h
    permitted.transform_values do |value|
      next if value.nil?
      value.to_s.strip.presence&.to_i
    end.compact
  end

  def default_prefill_data
    if @service_event.event_type_dump?
      site = @service_event.dump_site
      {
        customer_name: site&.name,
        customer_address: site&.location&.full_address,
        units_pumped: nil
      }
    else
      order = @service_event.order
      {
        customer_name: order&.customer&.display_name,
        customer_address: [ order&.location&.street, order&.location&.city, order&.location&.state, order&.location&.zip ].compact.join(', ').presence,
        units_pumped: order&.units&.count
      }
    end
  end

  def apply_estimated_gallons_override(report)
    return if @service_event.event_type_dump?

    gallons = report.data['estimated_gallons_pumped']
    return if gallons.blank?

    @service_event.update_column(:estimated_gallons_override, gallons.to_i)
  end

  def selected_month
    param = params[:month]
    return Date.current.beginning_of_month if param.blank?

    Date.strptime(param, '%Y-%m').beginning_of_month
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end
