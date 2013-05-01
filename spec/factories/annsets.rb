FactoryGirl.define do
  factory :annset do |a|
    a.user_id { |user| user.association(:user) }
  end
end