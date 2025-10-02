# frozen_string_literal: true

FactoryBot.define do
  factory :block do
    association :project
    association :doc
    sequence(:hid) { |n| "B#{n}" }
    obj { "TestBlock" }
    add_attribute(:begin) { 0 }
    add_attribute(:end) { 10 }
  end
end
