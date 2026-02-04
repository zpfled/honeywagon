class ForecastAccuracyController < ApplicationController
  def show
    company = current_user.company
    @logs = ForecastLog
            .where(company: company)
            .where('forecast_date >= ?', Date.current - 30)
            .order(forecast_date: :desc, provider: :asc)
  end
end
