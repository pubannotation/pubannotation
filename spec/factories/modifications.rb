FactoryGirl.define do
  factory :modification do |c|
    c.type 'Modification'
    c.hid 'R1'
    c.obj_id {|modification| modification.association(:obj)}
  end
end
