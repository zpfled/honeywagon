class ServiceEventsController < ApplicationController
  before_action :set_service_event, only: :update

  def update
    # TODO: View reads:
    # - None (redirect only).
    # TODO: Changes needed:
    # - None.
    if @service_event.update(service_event_params)
      redirect_to authenticated_root_path, notice: 'Service event updated.'
    else
      redirect_to authenticated_root_path, alert: @service_event.errors.full_messages.to_sentence
    end
  end

  private

  def set_service_event
    @service_event = current_user.service_events.find(params[:id])
  end

  def service_event_params
    params.require(:service_event).permit(:status)
  end
end
