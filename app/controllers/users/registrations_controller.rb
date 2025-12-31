module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      # TODO: View reads:
      # - Devise registration form on validation errors (resource + company_name).
      # TODO: Changes needed:
      # - None.
      permitted_params = sign_up_params
      company_name = permitted_params[:company_name]
      build_resource(permitted_params.except(:company_name))
      resource.company_name = company_name
      @company = Company.new(name: company_name)

      ActiveRecord::Base.transaction do
        @company.save!
        resource.company = @company
        resource.save!
      end

      yield resource if block_given?
      if resource.persisted?
        if resource.active_for_authentication?
          set_flash_message! :notice, :signed_up
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    rescue ActiveRecord::RecordInvalid => e
      if e.record == @company
        resource.errors.add(:company_name, e.record.errors.full_messages.to_sentence)
      end
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end

    private

    def sign_up_params
      params.require(:user).permit(:email, :password, :password_confirmation, :company_name)
    end
  end
end
