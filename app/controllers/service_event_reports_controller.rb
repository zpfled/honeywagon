class ServiceEventReportsController < ApplicationController
  before_action :set_service_event, only: [ :new, :create ]

  def index
    @reports = ServiceEventReport.includes(service_event: [ :service_event_type, { order: %i[customer location] } ])
      .order(created_at: :desc)
  end

  def new
    unless @service_event.report_required?
      redirect_to root_path, alert: 'This service event does not require a report.'
      return
    end

    @report = @service_event.service_event_report || @service_event.build_service_event_report(data: {})
    @report_fields = Array(@service_event.service_event_type&.report_fields)
    @prefill = default_prefill_data
  end

  def create
    @prefill = default_prefill_data
    report = @service_event.service_event_report || @service_event.build_service_event_report(data: {})
    report.data = report.data.merge(report_params.merge(
      'customer_name' => @prefill[:customer_name],
      'customer_address' => @prefill[:customer_address]
    ).compact)

    ServiceEvent.transaction do
      report.save!
      @service_event.update!(status: :completed)
    end

    redirect_to root_path, notice: 'Service event reported and completed.'
  rescue ActiveRecord::RecordInvalid => e
    @report = report
    @report_fields = Array(@service_event.service_event_type&.report_fields)
    @prefill = default_prefill_data
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def set_service_event
    @service_event = ServiceEvent.includes(order: [ :customer, :location, :units ]).find(params.permit(:service_event_id).require(:service_event_id))
  end

  def report_params
    params.fetch(:service_event_report, {}).permit(:estimated_gallons_pumped, :units_pumped).to_h
  end

  def default_prefill_data
    {
      customer_name: @service_event.order.customer&.display_name,
      customer_address: [ @service_event.order.location&.street, @service_event.order.location&.city, @service_event.order.location&.state, @service_event.order.location&.zip ].compact.join(', ').presence,
      units_pumped: @service_event.order.units.count
    }
  end
end
