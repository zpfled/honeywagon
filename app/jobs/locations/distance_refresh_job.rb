module Locations
  class DistanceRefreshJob < ApplicationJob
    queue_as :default

    def perform(location_id)
      location = Location.find_by(id: location_id)
      return unless location

      Locations::DistanceUpdater.call(location)
    end
  end
end
