# frozen_string_literal: true

FactoryBot.define do
  factory :relation do
    association :project
    association :doc
    sequence(:hid) { |n| "R#{n}" }
    pred { "TestRelation" }
    subj_id { nil }
    subj_type { "Denotation" }
    obj_id { nil }
  end
end
