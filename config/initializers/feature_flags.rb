# frozen_string_literal: true

Rails.application.configure do
  config.x.feature_flags ||= ActiveSupport::OrderedOptions.new

  # Route planning v2:
  # - remove RouteGenerationRun dependency
  # - replace-window generation semantics
  # - stop-based assignment as source of truth
  config.x.feature_flags.routes_replace_window_v2 =
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('FF_ROUTES_REPLACE_WINDOW_V2', 'false'))
end
