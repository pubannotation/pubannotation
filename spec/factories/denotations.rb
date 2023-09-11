FactoryBot.define do
  factory :denotation do
    project
    doc
    hid { 'T1' }
    add_attribute(:begin) { 0 }
    add_attribute(:end) { 4 }
    obj { 'subject' }
  end
end
