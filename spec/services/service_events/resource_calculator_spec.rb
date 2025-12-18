require 'rails_helper'

RSpec.describe ServiceEvents::ResourceCalculator do
  let(:company) { create(:company) }
  let(:order) { create(:order, company: company) }
  let(:standard_type) { create(:unit_type, :standard, company: company) }
  let(:ada_type) { create(:unit_type, :ada, company: company) }
  let(:handwash_type) { create(:unit_type, :handwash, company: company) }
  let!(:standard_plan) { create(:rate_plan, unit_type: standard_type) }
  let!(:ada_plan) { create(:rate_plan, unit_type: ada_type) }
  let!(:handwash_plan) { create(:rate_plan, unit_type: handwash_type) }

  before do
    create(:rental_line_item, order: order, unit_type: standard_type, rate_plan: standard_plan, quantity: 2)
    create(:rental_line_item, order: order, unit_type: ada_type, rate_plan: ada_plan, quantity: 1)
    create(:rental_line_item, order: order, unit_type: handwash_type, rate_plan: handwash_plan, quantity: 5)
  end

  describe '#usage' do
    it 'calculates delivery requirements' do
      event = create(:service_event, :delivery, order: order)
      usage = described_class.new(event).usage

      expect(usage[:trailer_spots]).to eq(6) # 2 standard + (1 ada * 2 spots) + 2 extra handwash
      expect(usage[:clean_water_gallons]).to eq((3 * 5) + (5 * 20))
      expect(usage[:septage_gallons]).to eq(0)
    end

    it 'calculates service requirements' do
      event = create(:service_event, :service, order: order)
      usage = described_class.new(event).usage

      expect(usage[:trailer_spots]).to eq(0)
      expect(usage[:clean_water_gallons]).to eq(21) # 3 toilets * 7
      expect(usage[:septage_gallons]).to eq(30)     # 3 toilets * 10
    end

    it 'includes service line item units for service events' do
      create(:service_line_item, order: order, units_serviced: 2)
      event = create(:service_event, :service, order: order)

      usage = described_class.new(event).usage
      # rental 3 + service-only 2 = 5 units -> 50 gallons
      expect(usage[:septage_gallons]).to eq(50)
    end

    it 'honors estimated gallons overrides for septage usage' do
      event = create(:service_event, :service, order: order, estimated_gallons_override: 75)
      usage = described_class.new(event).usage

      expect(usage[:septage_gallons]).to eq(75)
    end

    it 'calculates pickup requirements' do
      event = create(:service_event, :pickup, order: order)
      usage = described_class.new(event).usage

      expect(usage[:trailer_spots]).to eq(6)
      expect(usage[:clean_water_gallons]).to eq(3)  # 3 toilets * 1
      expect(usage[:septage_gallons]).to eq(30)
    end
  end
end
