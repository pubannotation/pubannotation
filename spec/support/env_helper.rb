# frozen_string_literal: true

module EnvHelper
  # Sets the given ENV vars (nil unsets one) for the block, restoring them afterwards: ENV is shared
  # across the whole run, so a change left behind would leak into whichever examples run next.
  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original&.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include EnvHelper
end
