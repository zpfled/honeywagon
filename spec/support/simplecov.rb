# frozen_string_literal: true

require 'simplecov'

SimpleCov.start 'rails' do
  enable_coverage :branch
  track_files 'app/**/*.rb'
  add_group 'Presenters', 'app/presenters'
  add_group 'Helpers', 'app/helpers'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_filter %w[bin/ db/ config/ spec/]
  # TODO: Raise thresholds after backfilling presenter/partial specs.
  minimum_coverage 80
  # TODO: Restore per-file enforcement once we improve coverage on lower-tested files.
  minimum_coverage_by_file 15
end

# Enforce minimal coverage for presenters/helpers as a CI guardrail (tunable).
SimpleCov.at_exit do
  result = SimpleCov.result

  group_threshold = 15.0
  failures = []

  {
    'Presenters' => result.groups['Presenters'],
    'Helpers' => result.groups['Helpers']
  }.each do |name, group|
    next unless group
    total_lines = group.covered_lines + group.missed_lines
    next if total_lines.zero?

    percent = (group.covered_lines * 100.0) / total_lines
    failures << "#{name} coverage #{percent.round(2)}% below minimum #{group_threshold}%" if percent < group_threshold
  end

  result.format!
  if failures.any?
    warn failures.join("\n")
    exit 2
  end
end
