FactoryGirl.define do
  factory :modann do |c|
    c.hid 'R1'
    c.modobj_id {|modann| modann.association(:modobj)}
    c.modobj_type 'type'
    c.modtype 'Negation'
    c.project_id {|modann| modann.association(:project)}
  end
end