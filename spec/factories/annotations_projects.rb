FactoryGirl.define do
  factory :annotations_project do |a|
    a.project_id { |project| project.association(:project)}
    a.annotation_id { |annotation| annotation.association(:annotation)}
  end
end
