# frozen_string_literal: true

FactoryBot.define do
  factory :medium do
    sequence(:sourcedb) { |n| "MediaDB#{n}" }
    sequence(:sourceid) { |n| "media_#{n}" }
    media_type { :image }
    content_type { 'image/jpeg' }
    association :user
  end
end
