# frozen_string_literal: true

FactoryBot.define do
  factory :denotation do
    association :project
    association :doc
    sequence(:hid) { |n| "T#{n}" }
    obj { "TestEntity" }
    begin_offset { 0 }
    end_offset { 4 }
  end
end
