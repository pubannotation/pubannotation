require 'logger'

Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  }

  logpath = Rails.root.join('log', 'sidekiq.log')
  config.logger = Logger.new(logpath, 'daily')
  config.logger.level = Logger::DEBUG
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  }
end