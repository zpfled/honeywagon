# frozen_string_literal: true

require 'bullet'

# Enable Bullet in tests to catch N+1s; raise in CI, log locally.
if defined?(Bullet)
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.raise = ENV['CI'].present?

  RSpec.configure do |config|
    config.before(:each, type: :request) { Bullet.start_request }
    config.after(:each, type: :request) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end

    config.before(:each, type: :system) { Bullet.start_request }
    config.after(:each, type: :system) do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
  end
end
