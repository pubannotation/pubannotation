FactoryGirl.define do
  factory :relation do |c|
    c.hid 'R1'
    c.relsub_id 1
    c.relsub_type 'Span' 
    c.relobj_id {|relation| relation.association(:relobj)}
    c.relobj_type 'Span'
    c.reltype 'coreferenceOf'
    c.project_id {|relation| relation.association(:project)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
  
  factory :subcatrel, :parent => :relation do |c|
    c.relsub_type 'Span' 
    c.relobj_id {|relobj| relobj.association(:relobj)}
    c.relobj_type 'Span'
    c.reltype 'coreferenceOf'
  end
  
  factory :subinsrel, :parent => :relation do |c|
    c.relsub_type 'Instance' 
    c.relobj_id {|relobj| relobj.association(:relobj)}
    c.relobj_type 'Instance'
    c.reltype 'coreferenceOf'
  end
end