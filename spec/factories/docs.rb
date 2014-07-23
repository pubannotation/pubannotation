FactoryGirl.define do
  factory :doc do |d|
    d.body 'body'
    d.sourcedb 'sourcedb'
    d.sourceid 'sourceid'
    d.sequence(:serial){|n| n}
  end
end
