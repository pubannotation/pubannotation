FactoryGirl.define do
  factory :annotator do |b|
    b.sequence(:abbrev){|n| "abbrev#{n}"}
  end
end
