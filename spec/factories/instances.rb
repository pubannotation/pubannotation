FactoryGirl.define do
  factory :instance do |c|
    c.hid 'E1'
    c.instype 'instanceOf'
    c.obj_id {|obj| obj.association(:obj)}
    c.project_id {|project| project.association(:project)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
end