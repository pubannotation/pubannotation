FactoryGirl.define do
  factory :associate_projects_project do |p|
     p.project_id {|project| project.association(:project)}
     p.associate_project_id {|project| project.association(:associate_project)}
  end
end