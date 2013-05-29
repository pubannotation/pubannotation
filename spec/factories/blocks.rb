FactoryGirl.define do
  factory :block do |b|
    b.hid 'T1'
    b.begin 1
    b.end 5
    b.category 'Protein'
    b.project_id {|project| project.association(:project)}
    b.doc_id {|doc| dob.association(:doc)}    
  end
end