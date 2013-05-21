FactoryGirl.define do
  factory :insann do |c|
    c.hid 'E1'
    c.instype 'instanceOf'
    c.insobj_id {|insobj| doc.association(:insobj)}
    c.project_id {|project| doc.association(:project)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
end