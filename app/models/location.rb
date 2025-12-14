# Location stores job sites, dump sites, and other places a truck may visit.
class Location < ApplicationRecord
  belongs_to :customer, optional: true

  # Scope returning sites flagged as dump facilities.
  scope :dump_sites, -> { where(dump_site: true) }
  # Scope returning active job/customer sites (non-dump).
  scope :job_sites,  -> { where(dump_site: false) }

  # Returns a single-line formatted street/city/state/zip string.
  def full_address
    [ street, city, state, zip ].compact.join(', ')
  end

  def display_label
    label.presence || full_address.presence || 'Unnamed location'
  end
end
