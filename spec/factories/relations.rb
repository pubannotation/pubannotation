FactoryGirl.define do
  factory :relation do |c|
    c.hid 'R1'
    c.subj_id 1
    c.subj_type 'Instance' 
    c.obj_id {|relation| relation.association(:obj)}
    c.obj_type 'Denotation'
    c.pred 'coreferenceOf'
  end
  
  factory :subcatrel, :parent => :relation do |c|
    c.obj_id {|obj| obj.association(:obj)}
    c.subj_type 'Annotation'
    c.obj_type 'Denotation'
    c.pred 'coreferenceOf'
  end
  
  factory :subinsrel, :parent => :relation do |c|
    c.subj_type 'Instance' 
    c.obj_id {|obj| obj.association(:obj)}
    c.obj_type 'Instance'
    c.pred 'coreferenceOf'
  end
  
  factory :block_relation, :parent => :relation do |c|
    c.subj_id {|subj| subj.association(:subj)}
    c.subj_type 'Block' 
    c.obj_id {|obj| obj.association(:obj)}
    c.obj_type 'Block' 
  end
end
