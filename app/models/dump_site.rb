# Represents a dump facility where trucks can empty septage tanks.
class DumpSite < ApplicationRecord
  belongs_to :company
  belongs_to :location

  accepts_nested_attributes_for :location

  validates :name, presence: true
end
