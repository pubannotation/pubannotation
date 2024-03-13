FactoryBot.define do
  factory :paragraph do
    doc { create(:doc) }
    label { 'p' }
    add_attribute(:begin) { 0 }
    add_attribute(:end) { 10 }
  end
end