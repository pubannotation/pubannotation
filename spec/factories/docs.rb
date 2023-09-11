FactoryBot.define do
  factory :doc do
    sourcedb { "PubMed" }
    sequence(:sourceid) { _1.to_s }
    body { "This is a test." }
  end
end
