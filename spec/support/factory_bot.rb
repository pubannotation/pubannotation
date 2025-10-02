# frozen_string_literal: true

RSpec.configure do |config|
  # Include FactoryBot methods for cleaner syntax
  # Use create(:user) instead of FactoryBot.create(:user)
  config.include FactoryBot::Syntax::Methods
end
