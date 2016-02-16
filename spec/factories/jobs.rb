FactoryGirl.define do
  factory :job do |p|
    p.project_id { |project| project.association(:project)}
  end
end
