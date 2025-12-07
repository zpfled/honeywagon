class Location < ApplicationRecord
  belongs_to :customer, optional: true

  scope :dump_sites, -> { where(dump_site: true) }
  scope :job_sites,  -> { where(dump_site: false) }

  def full_address
    [ street, city, state, zip ].compact.join(", ")
  end
end
