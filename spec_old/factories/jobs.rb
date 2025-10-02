# spec/factories/jobs.rb
FactoryBot.define do
  factory :job do
    sequence(:name) { "Job#{it}" }
    association :organization, factory: :project
  end
end
