FactoryBot.define do
  factory :doc do
    sourcedb { "PubMed" }
    sequence(:sourceid) { _1.to_s }
    body { "This is a test.\nTest are implemented.\nImplementation is difficult." }
  end
end
