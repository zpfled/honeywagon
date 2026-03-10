require "rails_helper"

RSpec.describe Routes::Planning::ReplaceWindow do
  let(:company) { create(:company) }
  let!(:truck) { create(:truck, company: company) }
  let!(:trailer) { create(:trailer, company: company) }
  let!(:user) { create(:user, company: company) }
  let(:window_start) { Date.current + 5.days }
  let(:window_end) { window_start + 2.days }

  def planner_result(route_plans:)
    Routes::CapacityRouting::Planner::Result.new(routes: route_plans, warnings: [], errors: [])
  end

  it "replaces existing routes in the selected window" do
    existing_route = create(:route, company: company, route_date: window_start, truck: truck, trailer: trailer)
    create(:service_event, :service, order: nil, route: existing_route, scheduled_on: window_start)

    planned_event = create(:service_event, :service, order: nil, scheduled_on: window_start + 1.day)
    route_plan = Routes::CapacityRouting::RouteBuilder::RoutePlan.new(
      date: planned_event.scheduled_on,
      stops: [ planned_event ],
      warnings: [],
      errors: []
    )
    allow(Routes::CapacityRouting::Planner).to receive(:call).and_return(planner_result(route_plans: [ route_plan ]))

    result = described_class.call(company: company, start_date: window_start, end_date: window_end, actor: user)

    expect(result).to be_success
    expect(result.replaced_routes_count).to eq(1)
    expect(Route.exists?(existing_route.id)).to be(false)
    expect(RouteStop.exists?(service_event_id: planned_event.id)).to be(true)
    expect(RouteStop.find_by(service_event_id: planned_event.id)&.route&.route_date).to eq(planned_event.scheduled_on)
  end

  it "preserves out-of-window routes while replacing overlapping window routes" do
    in_window_route = create(:route, company: company, route_date: window_start, truck: truck, trailer: trailer)
    create(:service_event, :service, order: nil, route: in_window_route, scheduled_on: window_start)

    out_of_window_route = create(:route, company: company, route_date: window_end + 2.days, truck: truck, trailer: trailer)
    outside_event = create(:service_event, :service, order: nil, route: out_of_window_route, scheduled_on: out_of_window_route.route_date)

    planned_event = create(:service_event, :service, order: nil, scheduled_on: window_start + 1.day)
    route_plan = Routes::CapacityRouting::RouteBuilder::RoutePlan.new(
      date: planned_event.scheduled_on,
      stops: [ planned_event ],
      warnings: [],
      errors: []
    )
    allow(Routes::CapacityRouting::Planner).to receive(:call).and_return(planner_result(route_plans: [ route_plan ]))

    result = described_class.call(company: company, start_date: window_start, end_date: window_end, actor: user)

    expect(result).to be_success
    expect(Route.exists?(out_of_window_route.id)).to be(true)
    expect(RouteStop.exists?(route_id: out_of_window_route.id, service_event_id: outside_event.id)).to be(true)
  end

  it "fails atomically when completed stops exist in the replacement window" do
    protected_route = create(:route, company: company, route_date: window_start, truck: truck, trailer: trailer)
    completed_event = create(:service_event, :service, :completed, order: nil, route: protected_route, scheduled_on: window_start)

    planned_event = create(:service_event, :service, order: nil, scheduled_on: window_start + 1.day)
    route_plan = Routes::CapacityRouting::RouteBuilder::RoutePlan.new(
      date: planned_event.scheduled_on,
      stops: [ planned_event ],
      warnings: [],
      errors: []
    )
    allow(Routes::CapacityRouting::Planner).to receive(:call).and_return(planner_result(route_plans: [ route_plan ]))

    result = described_class.call(company: company, start_date: window_start, end_date: window_end, actor: user)

    expect(result).not_to be_success
    expect(result.code).to eq(:completed_events_locked)
    expect(Route.exists?(protected_route.id)).to be(true)
    expect(RouteStop.exists?(route_id: protected_route.id, service_event_id: completed_event.id)).to be(true)
    expect(RouteStop.exists?(service_event_id: planned_event.id)).to be(false)
  end
end
