require 'rails_helper'

# TODO: Add money/date/time formatting specs when helper is implemented.
RSpec.describe FormattingHelper, type: :helper do
  it 'formats money' do
    expect(helper.format_money(1234)).to eq('$12.34')
  end

  it 'formats time in central time' do
    time = Time.find_zone('UTC').local(2024, 1, 1, 18, 30) # 12:30 PM CST
    expect(helper.format_time(time)).to eq('12:30 PM')
  end

  it 'formats dates' do
    date = Date.new(2024, 1, 5)
    expect(helper.format_date(date)).to eq('Jan 5, 2024')
  end

  it 'formats datetime in central time' do
    time = Time.find_zone('UTC').local(2024, 1, 1, 18, 30) # 12:30 PM CST
    formatted = helper.format_datetime(time)
    expect(formatted).to include('2024') # date part
    expect(formatted).to include('12:30 PM') # time part
    expect(formatted).to eq('Jan 1, 2024 12:30 PM')
  end
end
