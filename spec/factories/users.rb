FactoryBot.define do
  factory :user do
    sequence(:username) { "testuser#{_1}" }
    sequence(:email) { "testuser#{_1}@example.com" }
    password { "password" }
  end
end
