# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |_repo| "https://github.com/#{repo}.git" }

# Suporta versões 3.2+ com preferência por 3.3.x
ruby '>= 3.2.2'

gem 'importmap-rails', '1.1.5'
gem 'jbuilder', '2.14.1'
gem 'pg', '1.4.6 '
gem 'puma', '>= 6.4.3'
gem 'rack-cors', '2.0'
gem 'rails', '8.1.1'
gem 'rack', '>= 2.2.21'
gem 'sprockets-rails', '3.4.2'
gem 'stimulus-rails', '1.2.1'
gem 'turbo-rails', '1.4.0'

gem 'bootsnap', '1.16', require: false
gem 'tzinfo-data', '1.2022', platforms: %i[mingw mswin x64_mingw jruby]

gem 'roo', '2.10.0'
gem 'sidekiq', '>= 7.2.4'
gem 'dotenv-rails', '3.1.7'
gem 'rexml', '>= 3.3.9'
gem 'thor', '>= 1.4.0'
gem 'nokogiri', '>= 1.18.9'
gem 'net-imap', '>= 0.3.9'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'brakeman', '6.0.1'
  gem 'bundler-audit', '0.9.1'
  gem 'byebug', '11.1.3'
  gem 'colorize', '0.8.1', require: nil
  gem 'factory_bot_rails', '6.2'
  gem 'faker', '3.1.1'
  gem 'notifier', '1.2.2'
  gem 'rspec', '3.13.0'
  gem 'rspec-rails', '7.1.1'
  gem 'rubocop', '1.58.0', require: false
  gem 'rubocop-git', '0.1.3', require: false
  gem 'rubocop-performance', '1.19.1', require: false
  gem 'rubocop-rails', '2.22.2', require: false
  gem 'rubocop-rspec', '2.25.0', require: false
  gem 'rubocop-factory_bot', '2.24'
  gem 'rails-controller-testing', '1.0.5'
  gem 'shoulda-matchers', '5.3'
end

group :development do
  gem 'web-console'
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem 'spring'
end

group :test do
  gem 'fuubar', '2.5.1'
  gem 'simplecov', '0.22.0', require: false
end
