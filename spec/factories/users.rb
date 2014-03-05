FactoryGirl.define do
  factory :user do |u|
    u.sequence(:email){|n| "user_#{n}@factory_girl.net"}
    u.password 'password'
  end
end