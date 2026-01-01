class ServiceEventReportsController < ApplicationController
  before_action :set_service_event, only: [ :new, :create ]
  before_action :set_report, only: [ :edit, :update ]

  def index
    base_scope = current_user.service_event_reports
                              .includes(service_event: { order: %i[customer location] })
    if ServiceEvent.where(id: base_scope.select(:service_event_id), event_type: ServiceEvent.event_types[:dump]).exists?
      base_scope = base_scope.includes(service_event: { dump_site: :location })
    end
    @reports = base_scope
                           .joins(:service_event)
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
end
