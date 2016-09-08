FactoryGirl.define do
  factory :visit_log do |v|
    v.project_id {|visit_log| visit_log.association(:project)}
  end
end
