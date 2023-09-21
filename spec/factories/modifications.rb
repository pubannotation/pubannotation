FactoryBot.define do
  factory :modification do
    sequence(:hid) { |n| "M#{n}" }
  end
end
