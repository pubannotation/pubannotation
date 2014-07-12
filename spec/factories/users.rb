FactoryGirl.define do
  factory :user do |u|
    u.sequence(:email){|n| "user_#{n}@factory_girl.net"}
    u.sequence(:username){|n| "username #{n}"}
    u.password 'password'
  end
end
