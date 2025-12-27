# frozen_string_literal: true

# TODO: RoutePresenter should encapsulate route-level display data
# (summary stats, warnings, drive estimates) for views/partials.
class RoutePresenter
  def initialize(route)
    @route = route
  end

  private

  attr_reader :route
end
