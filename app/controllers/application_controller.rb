class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :ensure_company_setup!, if: :user_signed_in?

  private

  def ensure_company_setup!
    return if controller_path.start_with?('setup')
    return if current_user.company&.setup_completed?

    redirect_to setup_company_path, alert: 'Let’s finish setting up your company before continuing.'
  end
end
