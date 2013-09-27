FactoryGirl.define do
  factory :sproject do |a|
    a.user_id { |user| user.association(:user) }
    a.sequence(:name){|n| "#{n}#{Time.now}"}
  end
end