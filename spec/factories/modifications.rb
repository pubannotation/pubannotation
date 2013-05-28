FactoryGirl.define do
  factory :modification do |c|
    c.hid 'R1'
    c.obj_id {|modification| modification.association(:obj)}
    c.obj_type 'type'
    c.modtype 'Negation'
    c.project_id {|modification| modification.association(:project)}
  end
end