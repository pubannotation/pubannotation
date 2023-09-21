FactoryBot.define do
  factory :attrivute do
    sequence(:hid) { |n| "A#{n}" }
  end
end
