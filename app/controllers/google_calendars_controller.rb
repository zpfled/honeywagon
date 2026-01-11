class GoogleCalendarsController < ApplicationController
  def connect
    flash.delete(:alert) if flash[:alert] == I18n.t('devise.failure.already_authenticated')
    store_location_for(:user, params[:return_to].presence || request.referer || authenticated_root_path)
    redirect_to omniauth_authorize_path(:user, :google_oauth2), allow_other_host: true
  end
end
