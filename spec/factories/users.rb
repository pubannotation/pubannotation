FactoryBot.define do
  factory :user do
    username { "testuser" }
    email { "test@example.com" }
    password { "password" }
  end
end
