RSpec.describe RentalLineItem, type: :model do
  it 'is valid with defaults' do
    expect(build(:rental_line_item)).to be_valid
  end
end
