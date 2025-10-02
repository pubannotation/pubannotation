# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "test_project_#{n}" }
    accessibility { 1 } # Public

    trait :private do
      accessibility { 0 }
    end

    trait :with_docs do
      after(:create) do |project|
        create_list(:doc, 3).each do |doc|
          ProjectDoc.create!(project: project, doc: doc)
        end
      end
    end
  end
end
