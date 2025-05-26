FactoryBot.define do
  factory :sentence do
    sequence(:hid) { |n| "S#{n}" }
    obj { 'Sentence' }
  end
end
