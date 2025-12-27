# frozen_string_literal: true

# TODO: ServiceEventReportPresenter should format log row data (date/time,
# address, gallons/units) and rely on shared formatting helpers.
class ServiceEventReportPresenter
  def initialize(report)
    @report = report
  end

  private

  attr_reader :report
end
