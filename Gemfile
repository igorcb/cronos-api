source 'https://rubygems.org'
git_source(:github) { |_repo| "https://github.com/#{repo}.git" }

ruby '3.1.3'

gem 'importmap-rails', '1.1.5'
gem 'jbuilder', '2.11.5'
gem 'pg', '1.4.6 '
gem 'puma', '6.1.1'
gem 'sprockets-rails', '3.4.2'
gem 'stimulus-rails', '1.2.1'
gem 'turbo-rails', '1.4.0'
gem 'rack-cors', '2.0'
gem 'rails', '7.0.4.3'

gem 'bootsnap', '1.16', require: false
gem 'tzinfo-data', '1.2022', platforms: %i[mingw mswin x64_mingw jruby]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'byebug', '11.1.3'
  gem 'colorize', '0.8.1', require: nil
  gem 'factory_bot_rails', '6.2'
  gem 'faker', '3.1.1'
  gem 'notifier', '1.2.2'
  gem 'rspec', '3.12'
  gem 'rspec-rails', '6.0.1'
  gem 'rubocop', '1.48.1', require: false
  gem 'rubocop-git', '0.1.3', require: false
  gem 'rubocop-performance', '1.16.0 ', require: false
  gem 'rubocop-rails', '2.18.0', require: false
  gem 'rubocop-rspec', '2.19.0', require: false
  gem 'brakeman', '5.4.1'
  gem 'bundler-audit', '0.9.1'
  gem 'ruby_audit', '2.2.0'
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
