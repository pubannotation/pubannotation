FactoryBot.define do
  factory :block do
    project
    doc
    hid { 'B1' }
    add_attribute(:begin) { 0 }
    add_attribute(:end) { 14 }
    obj { '1st line' }

    factory :second_block do
      hid { 'B2' }
      add_attribute(:begin) { 16 }
      add_attribute(:end) { 37 }
      obj { '2nd line' }
    end

    factory :third_block do
      hid { 'B3' }
      add_attribute(:begin) { 39 }
      add_attribute(:end) { 63 }
      obj { '3rd line' }
    end
  end
end
