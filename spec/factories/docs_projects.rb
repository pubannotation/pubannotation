FactoryGirl.define do
  factory :docs_project do |d|
    d.doc_id {|doc| doc.association(:doc)}
  end
end