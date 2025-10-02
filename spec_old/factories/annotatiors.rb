# spec/factories/annotators.rb
FactoryBot.define do
  factory :annotator do
    sequence(:name) { "Annotator#{it}" }
    user
    url { "http://example.com/annotator" }
    add_attribute(:method) { "POST" }
  end
end
