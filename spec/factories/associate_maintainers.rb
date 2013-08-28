FactoryGirl.define do
  factory :associate_maintainer do |a|
    a.project_id {|associate| associate.association(:project)}
    a.user_id {|associate| associate.association(:user)}
  end
end