require "rails_helper"

RSpec.describe Routes::Generation::RunResolver do
  let(:company) { create(:company) }
  let(:scope_start) { Date.current.beginning_of_week(:sunday) }
  let(:scope_end) { scope_start + 27.days }

  let!(:scope) do
    Routes::Generation::Scope.new(company: company, scope_start: scope_start, scope_end: scope_end, strategy: "capacity_v1")
  end

  let!(:run) { create(:route_generation_run, company: company, state: :active, scope_key: scope.scope_key, window_start: scope.window_start, window_end: scope.window_end) }

  it "returns the requested run when it belongs to the same scope" do
    result = described_class.call(company: company, scope: scope, run_id: run.id)

    expect(result.status).to eq(:found)
    expect(result.run).to eq(run)
  end

  it "ignores a run id when it belongs to another scope" do
    other_scope = Routes::Generation::Scope.new(company: company, scope_start: scope_start + 7.days, scope_end: scope_end + 7.days, strategy: "capacity_v1")
    other_run = create(:route_generation_run, company: company, state: :active, scope_key: other_scope.scope_key, window_start: other_scope.window_start, window_end: other_scope.window_end)

    result = described_class.call(company: company, scope: scope, run_id: other_run.id)

    expect(result.run).to eq(run)
    expect(result.status).to eq(:found)
  end

  it "falls back to latest run when no active run exists for scope" do
    run.update!(state: :superseded, created_at: 2.days.ago)
    older_run = create(:route_generation_run, company: company, state: :active, scope_key: scope.scope_key, created_at: 1.day.ago)

    result = described_class.call(company: company, scope: scope, run_id: nil)

    expect(result.run).to eq(older_run)
    expect(result.status).to eq(:found)
  end

  it "returns missing when no run exists for scope" do
    company.route_generation_runs.where(scope_key: scope.scope_key).delete_all

    Routes::Generation::RunResolver.call(company: company, scope: scope).tap do |result|
      expect(result.status).to eq(:missing)
      expect(result.run).to be_nil
    end
  end
end
