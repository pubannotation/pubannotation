FactoryBot.define do
  factory :project do
    name { "TestProject" }
    user

    factory :another_project do
      name { "AnotherProject" }
    end
  end
end
