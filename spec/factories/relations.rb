FactoryGirl.define do
  factory :relation do |c|
    c.hid 'R1'
    c.subj_id 1
    c.subj_type 'Span' 
    c.obj_id {|relation| relation.association(:obj)}
    c.obj_type 'Span'
    c.pred 'coreferenceOf'
    c.project_id {|relation| relation.association(:project)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
  
  factory :subcatrel, :parent => :relation do |c|
    c.obj_id {|obj| obj.association(:obj)}
    c.obj_type 'Span'
    c.pred 'coreferenceOf'
  end
  
  factory :subinsrel, :parent => :relation do |c|
    c.subj_type 'Instance' 
    c.obj_id {|obj| obj.association(:obj)}
    c.obj_type 'Instance'
    c.pred 'coreferenceOf'
  end
end