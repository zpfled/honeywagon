# Location stores job sites, dump sites, and other places a truck may visit.
class Location < ApplicationRecord
  belongs_to :customer, optional: true

  before_validation :geocode_coordinates, if: :should_geocode?

  # Scope returning sites flagged as dump facilities.
  scope :dump_sites, -> { where(dump_site: true) }
  # Scope returning active job/customer sites (non-dump).
  scope :job_sites,  -> { where(dump_site: false) }

  # Returns a single-line formatted street/city/state/zip string.
  def full_address
    [ street, city, state, zip ].compact.join(', ')
  end

  # TODO: extract to a presenter
  def display_label
    return label if label.present?

    street_part = street.presence
    locality = city.presence || state.presence
    generated = [ street_part, locality ].compact.join(', ')

    generated.presence || full_address.presence || 'Unnamed location'
  end

  private

  def should_geocode?
    GoogleMaps.api_key.present? && full_address.present? && (lat.blank? || lng.blank?)
  end

  def geocode_coordinates
    result = Geocoding::GoogleClient.new.geocode(full_address)
    return unless result

    self.lat ||= result[:lat]
    self.lng ||= result[:lng]
  end
end
