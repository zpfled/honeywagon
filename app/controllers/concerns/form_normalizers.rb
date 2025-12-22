module FormNormalizers
  extend ActiveSupport::Concern

  private

  def normalize_price(value)
    return if value.blank?

    (BigDecimal(value.to_s) * 100).to_i
  rescue ArgumentError, TypeError
    nil
  end

  def normalize_decimal(value)
    return if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
