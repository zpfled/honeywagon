module Setup
  class CompaniesController < ApplicationController
    skip_before_action :ensure_company_setup!

    def show
      @company = current_user.company
      build_form_models
    end

    def update
      @company = current_user.company

      ActiveRecord::Base.transaction do
        @company.update!(company_params)
        persist_unit_types!
        persist_customers!
        @company.update!(setup_completed: true)
      end

      redirect_to authenticated_root_path, notice: 'Company profile completed.'
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      build_form_models
      render :show, status: :unprocessable_content
    end

    private

    def company_params
      params.require(:company).permit(:name)
    end

    def setup_params
      params.fetch(:setup, {}).permit(
        unit_types: %i[name slug prefix quantity],
        customers: %i[first_name last_name business_name billing_email phone]
      )
    end

    def build_form_models
      @unit_types = unit_type_entries.presence || default_unit_types
      @customers = customer_entries.presence || [ customer_defaults ]
    end

    def default_unit_types
      [
        { name: 'Standard Unit', slug: 'standard', prefix: 'S', quantity: 0 },
        { name: 'ADA Accessible Unit', slug: 'ada', prefix: 'A', quantity: 0 },
        { name: 'Handwash Station', slug: 'handwash', prefix: 'H', quantity: 0 }
      ]
    end

    def customer_defaults
      { first_name: '', last_name: '', business_name: '', billing_email: '', phone: '' }
    end

    def entries_for(key)
      raw = setup_params[key]
      return [] unless raw.present?

      collection =
        if raw.is_a?(Array)
          raw
        else
          raw.respond_to?(:values) ? raw.values : Array(raw)
        end

      collection.map { |entry| entry.to_h.symbolize_keys }
    end

    def unit_type_entries
      entries_for(:unit_types)
    end

    def customer_entries
      entries_for(:customers)
    end

    def persist_unit_types!
      unit_type_entries.each do |attrs|
        next if attrs[:name].blank?
        slug = attrs[:slug].presence || attrs[:name].parameterize
        prefix = attrs[:prefix].presence || attrs[:name].first.upcase
        quantity = attrs[:quantity].to_i

        unit_type = current_user.company.unit_types.find_or_initialize_by(slug: slug)
        unit_type.name = attrs[:name]
        unit_type.prefix = prefix
        unit_type.save!

        ensure_unit_inventory(unit_type, quantity)
      end
    end

    def ensure_unit_inventory(unit_type, target_quantity)
      return if target_quantity <= 0

      current_count = unit_type.units.count
      missing = target_quantity - current_count
      return unless missing.positive?

      missing.times do
        current_user.company.units.create!(unit_type: unit_type, manufacturer: 'Setup', status: 'available')
      end
    end

    def persist_customers!
      customer_entries.each do |attrs|
        next if customer_blank?(attrs)
        current_user.company.customers.create!(attrs)
      end
    end

    def customer_blank?(attrs)
      key_fields = attrs.slice(:first_name, :last_name, :business_name, :billing_email)
      key_fields.values.all?(&:blank?)
    end
  end
end
