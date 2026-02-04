module Weather
  class ForecastRefresher
    COOLDOWN = 24.hours

    def self.call(company:)
      new(company: company).call
    end

    def initialize(company:)
      @company = company
    end

    def call
      return unless company
      return if recently_refreshed?

      Weather::ForecastRefreshJob.perform_later(company.id)
    end

    private

    attr_reader :company

    def recently_refreshed?
      company.forecast_refresh_at.present? && company.forecast_refresh_at > COOLDOWN.ago
    end
  end
end
