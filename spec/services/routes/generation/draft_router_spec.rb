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
end
