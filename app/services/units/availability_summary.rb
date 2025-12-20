# frozen_string_literal: true

module Units
  class AvailabilitySummary
    attr_reader :company, :start_date, :end_date

    def initialize(company:, start_date:, end_date:)
      @company = company
      @start_date = parse_date(start_date)
      @end_date = parse_date(end_date)
    end

    def summary
      return [] unless valid_range?

      counts = Unit.available_between(start_date, end_date)
                   .where(company_id: company.id)
                   .group(:unit_type_id)
                   .count

      company.unit_types.order(:name).map do |unit_type|
        { unit_type: unit_type, available: counts[unit_type.id] || 0 }
      end
    end

    def valid_range?
      start_date.present? && end_date.present? && start_date <= end_date
    end

    private

    def parse_date(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
