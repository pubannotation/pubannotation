FactoryGirl.define do
  factory :project do |a|
    a.user_id { |user| user.association(:user)}
    a.sequence(:name){|n| "name#{ n}"}
  end
end
