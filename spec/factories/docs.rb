# frozen_string_literal: true

FactoryBot.define do
  factory :doc do
    sequence(:sourcedb) { |n| "TestDB#{n}" }
    sequence(:sourceid) { |n| "doc_#{n}" }
    body { "This is a test document body." }

    trait :with_long_body do
      body { "This is a much longer test document body. " * 100 }
    end
  end
end
