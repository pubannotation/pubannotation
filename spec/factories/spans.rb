FactoryGirl.define do
  factory :span do |c|
    c.hid 'T1'
    c.begin 1
    c.end 5
    c.category 'Protein'
    c.project_id {|project| doc.association(:project)}
    c.doc_id {|doc| doc.association(:doc)}
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
end