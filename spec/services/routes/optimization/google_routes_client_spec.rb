require 'rails_helper'

RSpec.describe Routes::Optimization::GoogleRoutesClient do
  let(:client) { described_class.new(api_key: 'fake-key') }

  describe '#optimize' do
    it 'requires an API key' do
      result = described_class.new(api_key: nil).optimize([])

      expect(result.success?).to be(false)
      expect(result.errors).to include('Google routing API key is not configured.')
    end

    it 'returns failure when Google responds with an error' do
      allow(client).to receive(:request_json).and_return({ 'error' => { 'message' => 'Disabled' } })

      result = client.optimize([ { id: 'a', lat: 0, lng: 0 }, { id: 'b', lat: 1, lng: 1 } ])

      expect(result).not_to be_success
      expect(result.errors).to include('Disabled')
    end

    it 'returns legs data on success' do
      payload = {
        'routes' => [
          {
            'distanceMeters' => 1000,
            'duration' => '100s',
            'legs' => [
              { 'distanceMeters' => 250, 'duration' => '25s' },
              { 'distanceMeters' => 750, 'duration' => '75s' }
            ],
            'optimizedIntermediateWaypointIndex' => []
          }
        ]
      }
      allow(client).to receive(:request_json).and_return(payload)

      result = client.optimize([ { id: 'a', lat: 0, lng: 0 }, { id: 'b', lat: 1, lng: 1 } ])

      expect(result).to be_success
      expect(result.legs.length).to eq(2)
      expect(result.legs.first[:distance_meters]).to eq(250)
      expect(result.legs.first[:duration_seconds]).to eq(25)
    end
  end
end
