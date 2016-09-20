FactoryGirl.define do
  factory :div do |d|
    d.doc_id { |d| d.association(:doc)}
  end
end
