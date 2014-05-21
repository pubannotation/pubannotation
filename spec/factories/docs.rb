FactoryGirl.define do
  factory :doc do |d|
    d.body 'body'
    d.sourcedb 'sourcedb'
    d.sourceid 'sourceid'
    d.serial 0
  end
end
