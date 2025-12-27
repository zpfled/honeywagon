# frozen_string_literal: true

# TODO: StopPresenter should format per-stop details (leg distance, fuel cost,
# customer/address, usage) to keep views free of model/presentation logic.
class StopPresenter
  def initialize(service_event)
    @service_event = service_event
  end

  private

  attr_reader :service_event
end
