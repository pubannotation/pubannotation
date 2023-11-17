FactoryBot.define do
  factory :project do
    sequence(:name) { "TestProject#{_1.to_s}" }
    user

    factory :another_project do
      name { "AnotherProject" }
    end
  end
end
