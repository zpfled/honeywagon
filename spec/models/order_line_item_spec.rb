RSpec.describe OrderLineItem, type: :model do
  it 'is valid with defaults' do
    expect(build(:order_line_item)).to be_valid
  end
end
