FactoryBot.define do
  factory :denotation do
    project
    doc
    hid { 'T1' }
    add_attribute(:begin) { 0 }
    add_attribute(:end) { 4 }
    obj { 'subject' }

    factory :object_denotation do
      hid { 'T2' }
      add_attribute(:begin) { 10 }
      add_attribute(:end) { 14 }
      obj { 'object' }
    end

    factory :verb_denotation do
      hid { 'T3' }
      add_attribute(:begin) { 6 }
      add_attribute(:end) { 7 }
      obj { 'verb' }
    end
  end
end
