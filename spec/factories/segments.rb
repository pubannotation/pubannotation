# frozen_string_literal: true

FactoryBot.define do
  factory :segment do
    # One with no segments of its own, which this one could overlap.
    association :media_transcript, segments: []
    sequence(:sort_order) { |n| n }
    text { 'Hello' }
    start_ms { 0 }
    end_ms { 300 }
  end
end
