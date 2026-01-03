module Companies
  class UnitInventoryForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.blank? || params[:unit_type_id].blank? || params[:quantity].blank?

      unit_type = company.unit_types.find(params[:unit_type_id])
      target = params[:quantity].to_i
      raise ActiveRecord::RecordInvalid.new(unit_type), 'Quantity must be zero or greater.' if target.negative?

      current = unit_type.units.count
      difference = target - current
      return if difference.zero?

      if difference.positive?
        difference.times { company.units.create!(unit_type: unit_type, status: 'available') }
      else
        remove_units!(unit_type, difference.abs)
      end
    end

    private

    attr_reader :company, :params

    def remove_units!(unit_type, needed)
      removable = unit_type.units.where(status: 'available').order(created_at: :desc)
      if removable.count < needed
        unit_type.errors.add(:base, "Only #{removable.count} available units can be removed right now.")
        raise ActiveRecord::RecordInvalid.new(unit_type)
      end

      removable.limit(needed).each(&:destroy!)
    end
  end
end
