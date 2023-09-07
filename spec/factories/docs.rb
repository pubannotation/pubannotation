FactoryBot.define do
  factory :doc do
    sourcedb { "PubMed" }
    sourceid { "12345678" }
    body { "This is a test." }
  end
end
