require 'rails_helper'

RSpec.describe Routes::CapacityRouting::Clusterer do
  Candidate = Struct.new(:location)

  def build_candidate(lat:, lng:)
    customer = create(:customer, company: company)
    location = create(:location, customer: customer, lat: lat, lng: lng)
    Candidate.new(location)
  end

  let(:company) { create(:company, :with_home_base) }

  describe '#clusters' do
    it 'separates opposite-direction candidates when they are not near each other' do
      # These two stops are roughly equidistant from home base, but far apart
      # from each other. Neighbor-based clustering should split them.
      east = build_candidate(lat: 43.0, lng: -89.9)
      west = build_candidate(lat: 43.0, lng: -90.1)

      result = described_class.new(company: company, candidates: [ east, west ]).clusters

      expect(result).to match_array([ [ east ], [ west ] ])
    end

    it 'clusters nearby candidates together' do
      a = build_candidate(lat: 43.0, lng: -90.0)
      b = build_candidate(lat: 43.0, lng: -89.95)

      result = described_class.new(company: company, candidates: [ a, b ]).clusters

      expect(result).to eq([ [ a, b ] ])
    end

    it 'uses neighbor chains to build a single connected cluster' do
      # A<->B and B<->C are close enough, while A<->C is farther than the
      # threshold. Connected-components logic should still keep all three
      # together through B.
      a = build_candidate(lat: 43.0, lng: -90.0)
      b = build_candidate(lat: 43.0, lng: -89.93)
      c = build_candidate(lat: 43.0, lng: -89.86)

      result = described_class.new(company: company, candidates: [ a, b, c ]).clusters

      expect(result).to eq([ [ a, b, c ] ])
    end
  end
end
