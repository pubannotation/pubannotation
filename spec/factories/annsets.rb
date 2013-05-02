FactoryGirl.define do
  factory :annset do |a|
    a.user_id { |user| user.association(:user) }
    a.sequence(:name){|n| "#{Time.now + n}name"}
  end
end