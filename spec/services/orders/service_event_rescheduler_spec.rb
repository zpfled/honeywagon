require 'rails_helper'

RSpec.describe Orders::ServiceEventRescheduler do
  include ActiveSupport::Testing::TimeHelpers

  describe '#shift_from' do
    let(:base_date) { Date.new(2024, 1, 1) }
    let(:order) { create(:order, start_date: base_date - 10, end_date: base_date + 60) }

    before do
      allow(Orders::ServiceScheduleResolver).to receive(:interval_days).and_call_original
      travel_to base_date
    end

    after { travel_back }

    context 'when the order has no interval' do
      it 'does nothing' do
        allow(Orders::ServiceScheduleResolver).to receive(:interval_days).with(order).and_return(nil)
        rescheduler = described_class.new(order)

        expect do
          rescheduler.shift_from(completion_date: Date.current)
        end.not_to change { order.service_events.count }
      end
    end

    context 'with a weekly cadence' do
      let(:route) { create(:route, company: order.company, route_date: Date.current + 5) }
      let!(:event1) { create(:service_event, order: order, event_type: :service, scheduled_on: Date.current + 5, route: route, route_date: route.route_date) }
      let!(:event2) { create(:service_event, order: order, event_type: :service, scheduled_on: Date.current + 9) }
      let!(:manual_event) { create(:service_event, order: order, event_type: :service, scheduled_on: Date.current + 12, auto_generated: false) }

      before do
        allow(Orders::ServiceScheduleResolver).to receive(:interval_days).with(order).and_return(7)
      end

      it 'shifts all future events preserving cadence and backfills routes' do
        described_class.new(order).shift_from(completion_date: Date.current)

        expect(event1.reload.scheduled_on).to eq(Date.current + 7)
        expect(event1.route).to_not be_nil
        expect(event1.route_date).to eq(Date.current + 7)

        expect(event2.reload.scheduled_on).to eq(Date.current + 14)
        expect(manual_event.reload.scheduled_on).to eq(Date.current + 21)
      end

      it 'drops events that would exceed the order end date' do
        order.update!(end_date: Date.current + 15)
        near_end = create(:service_event, order: order, event_type: :service, scheduled_on: order.end_date - 1)

        described_class.new(order).shift_from(completion_date: Date.current)

        expect { near_end.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
