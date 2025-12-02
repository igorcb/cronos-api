require 'sidekiq/rails'

sidekiq_config = {
  url: ENV['REDIS_URL'],
  network_timeout: 10,
}

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end
