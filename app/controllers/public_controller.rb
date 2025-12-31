class PublicController < ApplicationController
  skip_before_action :authenticate_user!, only: :landing

  def landing
    # TODO: View reads:
    # - No dynamic data (static landing page).
    # TODO: Changes needed:
    # - None.
  end
end
