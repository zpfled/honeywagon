require "rails_helper"

RSpec.describe Routes::Generation::DraftRouter do
  let(:company) { create(:company) }
  let(:truck) { create(:truck, company: company) }
  let(:scope_start) { Date.current.beginning_of_week(:sunday) }
  let(:scope_end) { scope_start + 27.days }
  let!(:scope) { Routes::Generation::Scope.new(company: company, scope_start: scope_start, scope_end: scope_end, strategy: "capacity_v1") }

  RoutePlan = Struct.new(:date, :stops)

  before do
    order = create(:order, company: company, status: "scheduled", start_date: scope_start, end_date: scope_end)
    source_route = create(:route, company: company, truck: truck, route_date: scope_start)
    @first_service_event = create(:service_event, :service, order: order, route: source_route, scheduled_on: scope_start, route_date: scope_start)
    planning = instance_double(
      "Routes::CapacityRouting::Plan",
      routes: [
        RoutePlan.new(scope_start, [ @first_service_event ])
      ],
      warnings: [],
      errors: []
    )
    allow(Routes::CapacityRouting::Planner).to receive(:call)
      .with(hash_including(company: company, start_date: scope.window_start, horizon_days: 3))
      .and_return(planning)
  end

  it "creates a new run and projects stops into generated routes" do
    result = described_class.call(
      company: company,
      scope: scope,
      horizon_days: 3,
      replace: true,
      created_by: create(:user, company: company)
    )

    expect(result.run).to be_present
    expect(result.run).to be_active
    expect(result.routes.size).to eq(1)

    generated_route = result.routes.first
    expect(generated_route.route_stops.size).to eq(1)
    expect(generated_route.route_stops.first.position).to eq(0)
    expect(generated_route.stop_service_events).to include(@first_service_event)
    expect(@first_service_event.reload.route).to eq(generated_route)
    expect(@first_service_event.reload.route_sequence).to eq(0)
  end

  it "supersedes prior active runs for the same scope when replace=true" do
    existing_run = create(
      :route_generation_run,
      company: company,
      scope_key: scope.scope_key,
      state: :active,
      window_start: scope.window_start,
      window_end: scope.window_end
    )

    result = described_class.call(
      company: company,
      scope: scope,
      horizon_days: 3,
      replace: true,
      created_by: create(:user, company: company)
    )

    expect(result.run).to be_active
    expect(existing_run.reload).to be_superseded
    expect(result.run).not_to eq(existing_run)
  end

  it "preserves non-overlapping planned days when a new 3-day window overlaps by one day" do
    user = create(:user, company: company)
    order = create(:order, company: company, status: "scheduled", start_date: scope_start, end_date: scope_end)
    day1 = scope_start
    day2 = scope_start + 1.day
    day3 = scope_start + 2.days
    day4 = scope_start + 3.days
    day5 = scope_start + 4.days

    event_day1 = create(:service_event, :service, order: order, scheduled_on: day1, route_date: day1)
    event_day2 = create(:service_event, :service, order: order, scheduled_on: day2, route_date: day2)
    event_day3 = create(:service_event, :service, order: order, scheduled_on: day3, route_date: day3)
    event_day4 = create(:service_event, :service, order: order, scheduled_on: day4, route_date: day4)
    event_day5 = create(:service_event, :service, order: order, scheduled_on: day5, route_date: day5)

    first_plan = instance_double(
      "Routes::CapacityRouting::Plan",
      routes: [
        RoutePlan.new(day1, [ event_day1 ]),
        RoutePlan.new(day2, [ event_day2 ]),
        RoutePlan.new(day3, [ event_day3 ])
      ],
      warnings: [],
      errors: []
    )

    second_plan = instance_double(
      "Routes::CapacityRouting::Plan",
      routes: [
        RoutePlan.new(day3, [ event_day3 ]),
        RoutePlan.new(day4, [ event_day4 ]),
        RoutePlan.new(day5, [ event_day5 ])
      ],
      warnings: [],
      errors: []
    )

    allow(Routes::CapacityRouting::Planner).to receive(:call)
      .with(hash_including(company: company, start_date: day1, horizon_days: 3))
      .and_return(first_plan)
    allow(Routes::CapacityRouting::Planner).to receive(:call)
      .with(hash_including(company: company, start_date: day3, horizon_days: 3))
      .and_return(second_plan)

    first_result = described_class.call(
      company: company,
      scope: scope,
      horizon_days: 3,
      planning_start_date: day1,
      replace: true,
      created_by: user
    )

    first_run = first_result.run
    expect(first_run).to be_active
    expect(first_run.routes.pluck(:route_date)).to match_array([ day1, day2, day3 ])

    second_result = described_class.call(
      company: company,
      scope: scope,
      horizon_days: 3,
      planning_start_date: day3,
      replace: true,
      created_by: user
    )

    second_run = second_result.run
    expect(second_run).to be_active
    expect(first_run.reload).to be_superseded

    # Day 1-2 are carried forward from prior run; day 3-5 are replaced/generated.
    expect(second_run.routes.pluck(:route_date)).to match_array([ day1, day2, day3, day4, day5 ])
    expect(second_run.routes.where(route_date: day1).count).to eq(1)
    expect(second_run.routes.where(route_date: day2).count).to eq(1)
    expect(second_run.routes.where(route_date: day3).count).to eq(1)
    expect(second_run.routes.where(route_date: day4).count).to eq(1)
    expect(second_run.routes.where(route_date: day5).count).to eq(1)
  end
end
