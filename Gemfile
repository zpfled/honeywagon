source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.0'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use Postgres as Rails database
gem 'pg'
# Use devise for authentication
gem 'devise'
# OAuth for Google Calendar
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'google-apis-calendar_v3'
# Use pundit for authorization
gem 'pundit'
# Use Sidekiq for background jobs
gem 'sidekiq'
# Use pagy for pagination
gem 'pagy'
# Use money-rails for handling currency
gem 'money-rails'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[ mingw x64_mingw mswin jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

group :development, :test do
  gem 'factory_bot_rails'
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri mingw x64_mingw mswin ], require: 'debug/prelude'

  # N+1 detection in dev/test (raise in CI request specs)
  gem 'bullet'

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', '~>7.1.2', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'
  gem 'pry-rails'
  gem 'htmlbeautifier'
end

group :test do
  gem 'rails-controller-testing'
  gem 'rspec-rails'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'timecop'
  gem 'simplecov', require: false
end

gem 'rubocop', '~> 1.82', group: :development
gem 'rubocop-rails', '~> 2.34', group: :development
gem 'rubocop-performance', '~> 1.26', group: :development

gem 'tailwindcss-rails', '~> 4.4'

gem 'foreman', '~> 0.90.0'

gem 'ruby-lsp', '~> 0.26.5'
