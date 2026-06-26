# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "testuser#{n}" }
    sequence(:email) { |n| "testuser#{n}@example.com" }
    password { "password" }
    can_use_media { true }
  end
end
