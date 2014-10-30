FactoryGirl.define do
  factory :notice do |n|
    n.project_id {|notice| notice.association(:project)}
  end
end
