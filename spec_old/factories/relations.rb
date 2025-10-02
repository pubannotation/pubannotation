FactoryBot.define do
  factory :relation do
    sequence(:hid) { |n| "R#{n}" }
  end
end
