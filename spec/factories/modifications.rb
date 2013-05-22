FactoryGirl.define do
  factory :modification do |c|
    c.hid 'R1'
    c.modobj_id {|modification| modification.association(:modobj)}
    c.modobj_type 'type'
    c.modtype 'Negation'
    c.project_id {|modification| modification.association(:project)}
  end
end