module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :require_no_authentication, raise: false, only: %i[passthru google_oauth2]
    before_action :clear_already_authenticated_flash, only: %i[passthru google_oauth2]
    skip_before_action :ensure_company_setup!, raise: false

    def google_oauth2
      return redirect_to(new_user_session_path, alert: 'Please sign in first.') unless current_user

      auth = request.env['omniauth.auth']
      if auth.present?
        current_user.update_google_calendar_tokens(auth)
        Rails.logger.info(
          message: 'Google OAuth connected',
          user_id: current_user.id,
          has_access_token: current_user.google_calendar_access_token.present?,
          has_refresh_token: current_user.google_calendar_refresh_token.present?,
          expires_at: current_user.google_calendar_expires_at
        )
        flash.delete(:alert)
        redirect_to stored_location_for(:user) || authenticated_root_path, notice: 'Google Calendar connected.'
      else
        Rails.logger.warn(
          message: 'Google OAuth missing auth payload',
          user_id: current_user.id
        )
        redirect_to stored_location_for(:user) || authenticated_root_path, alert: 'Unable to connect Google Calendar.'
      end
    end

    def failure
      error = request.env['omniauth.error']
      error_type = request.env['omniauth.error.type']
      Rails.logger.warn(
        message: 'Google OAuth failure',
        user_id: current_user&.id,
        error_type: error_type,
        error_class: error&.class&.name,
        error_message: error&.message
      )

      redirect_to stored_location_for(:user) || authenticated_root_path,
                  alert: 'Google Calendar connection failed. Please try again.'
    end

    private

    def clear_already_authenticated_flash
      message = I18n.t('devise.failure.already_authenticated')
      flash.delete(:alert) if flash[:alert] == message
    end
  end
end
