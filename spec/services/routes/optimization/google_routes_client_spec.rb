require 'rails_helper'

RSpec.describe Routes::Optimization::GoogleRoutesClient do
  let(:client) { described_class.new(api_key: 'test-key') }

  describe '#optimize' do
    it 'requires an API key' do
      expect(described_class.new(api_key: nil).optimize([]).success?).to be(false)
    end

    it 'returns a failure when Google responds with an error' do
      allow(client).to receive(:request_json).and_return({ 'error' => { 'message' => 'API disabled' } })

      result = client.optimize([
        { id: 'a', lat: 0, lng: 0 },
        { id: 'b', lat: 1, lng: 1 }
      ])
      expect(result).not_to be_success
    end
  end
end
