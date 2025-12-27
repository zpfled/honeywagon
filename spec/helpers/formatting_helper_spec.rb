require 'rails_helper'

# TODO: Add money/date/time formatting specs when helper is implemented.
RSpec.describe FormattingHelper, type: :helper do
  it 'is available in views/helpers' do
    expect(helper).to be_a(FormattingHelper)
  end
end
