FactoryGirl.define do
  factory :relann do |c|
    c.hid 'R1'
    c.relsub_id 1
    c.relsub_type 'Catann' 
    c.relobj_id {|relann| relann.association(:relobj)}
    c.relobj_type 'Catann'
    c.reltype 'coreferenceOf'
    c.annset_id {|relann| relann.association(:annset)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
  
  factory :subcatrel, :parent => :relann do |c|
    c.relsub_type 'Catann' 
    c.relobj_id {|relobj| relobj.association(:relobj)}
    c.relobj_type 'Catann'
    c.reltype 'coreferenceOf'
  end
  
  factory :subinsrel, :parent => :relann do |c|
    c.relsub_type 'Insann' 
    c.relobj_id {|relobj| relobj.association(:relobj)}
    c.relobj_type 'Insann'
    c.reltype 'coreferenceOf'
  end
end