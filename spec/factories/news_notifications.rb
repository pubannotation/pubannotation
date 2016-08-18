FactoryGirl.define do
  factory :news_notification do |u|
    u.sequence(:title){|n| "News Title #{n}"}
    u.sequence(:body){|n| "News body #{n}"}
  end
end
