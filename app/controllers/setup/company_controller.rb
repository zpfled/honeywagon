module Setup
  class CompanyController < ApplicationController
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
        persist_units!
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
        unit_types: %i[name slug prefix],
        units: %i[unit_type_slug quantity],
        customers: %i[first_name last_name company_name billing_email phone]
      )
    end

    def build_form_models
      @unit_types = setup_params[:unit_types].presence || default_unit_types
      @unit_counts = setup_params[:units].presence || []
      @customers = setup_params[:customers].presence || [ customer_defaults ]
    end

    def default_unit_types
      [
        { name: 'Standard Unit', slug: 'standard', prefix: 'S' },
        { name: 'ADA Accessible Unit', slug: 'ada', prefix: 'A' },
        { name: 'Handwash Station', slug: 'handwash', prefix: 'H' }
      ]
    end

    def customer_defaults
      { first_name: '', last_name: '', company_name: '', billing_email: '', phone: '' }
    end

    def persist_unit_types!
      Array(setup_params[:unit_types]).each do |attrs|
        next if attrs[:name].blank?
        slug = attrs[:slug].presence || attrs[:name].parameterize
        current_user.company.unit_types.find_or_create_by!(slug: slug) do |ut|
          ut.name = attrs[:name]
          ut.prefix = attrs[:prefix].presence || attrs[:name].first.upcase
        end
      end
    end

    def persist_units!
      Array(setup_params[:units]).each do |attrs|
        slug = attrs[:unit_type_slug]
        next if slug.blank?
        unit_type = current_user.company.unit_types.find_by(slug: slug)
        next unless unit_type
        quantity = attrs[:quantity].to_i
        next if quantity <= 0

        quantity.times do
          current_user.company.units.create!(unit_type: unit_type, manufacturer: 'Setup', status: 'available')
        end
      end
    end

    def persist_customers!
      Array(setup_params[:customers]).each do |attrs|
        next if attrs.values.all?(&:blank?)
        customer = current_user.company.customers.new(attrs)
        customer.save!
      end
    end
  end
end
