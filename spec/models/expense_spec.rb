require 'rails_helper'

RSpec.describe Expense, type: :model do
  subject { build(:expense) }

  it 'requires a name' do
    expense = build(:expense, name: nil)
    expect(expense).not_to be_valid
    expect(expense.errors[:name]).to be_present
  end

  it 'requires category to be in whitelist' do
    expense = build(:expense, category: 'invalid')
    expect(expense).not_to be_valid
  end

  it 'requires cost_type to be in whitelist' do
    expense = build(:expense, cost_type: 'invalid')
    expect(expense).not_to be_valid
  end

  it 'requires base amount to be positive' do
    expense = build(:expense, base_amount: -5)
    expect(expense).not_to be_valid
  end

  describe '#per_unit_cost' do
    it 'returns base amount when package size missing' do
      expense = build(:expense, base_amount: 100, package_size: nil)
      expect(expense.per_unit_cost).to eq 100
    end

    it 'divides by package size' do
      expense = build(:expense, base_amount: 120, package_size: 6)
      expect(expense.per_unit_cost).to eq 20
    end
  end

  describe '#applies_to_all?' do
    it 'true when empty' do
      expense = build(:expense, applies_to: [])
      expect(expense.applies_to_all?).to be true
    end

    it 'true when includes all' do
      expense = build(:expense, applies_to: ['all'])
      expect(expense.applies_to_all?).to be true
    end

    it 'false otherwise' do
      expense = build(:expense, applies_to: ['service'])
      expect(expense.applies_to_all?).to be false
    end
  end
end
