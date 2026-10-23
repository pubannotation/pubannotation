# frozen_string_literal: true

FactoryBot.define do
  factory :segment do
    association :media_transcript
    sequence(:sort_order) { |n| n }
    text { 'Hello' }
    start_ms { 0 }
    end_ms { 300 }
  end
end
