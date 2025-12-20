require 'rails_helper'

RSpec.describe Units::AvailabilitySummary do
  let(:company) { create(:company) }
  let(:unit_type) { create(:unit_type, company: company) }
  let!(:free_unit) { create(:unit, company: company, unit_type: unit_type, status: 'available') }
  let!(:maintenance_unit) { create(:unit, company: company, unit_type: unit_type, status: 'maintenance') }
  let!(:overlapping_unit) { create(:unit, company: company, unit_type: unit_type, status: 'available') }
  let!(:order) do
    create(:order,
           company: company,
           status: 'scheduled',
           start_date: Date.current,
           end_date: Date.current + 5.days)
  end
  let!(:order_unit) { create(:order_unit, order: order, unit: overlapping_unit) }

  describe '#summary' do
    it 'excludes overlapping and maintenance units' do
      summary = described_class.new(
        company: company,
        start_date: Date.current + 1.day,
        end_date: Date.current + 2.days
      ).summary

      entry = summary.find { |row| row[:unit_type] == unit_type }
      expect(entry[:available]).to eq(1)
    end

    it 'returns empty when range invalid' do
      summary = described_class.new(
        company: company,
        start_date: '2024-01-10',
        end_date: '2024-01-01'
      )

      expect(summary.valid_range?).to be_falsey
      expect(summary.summary).to eq([])
    end
  end
end
