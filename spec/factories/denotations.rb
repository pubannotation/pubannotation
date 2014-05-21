FactoryGirl.define do
  factory :denotation do |c|
    c.hid 'T1'
    c.begin 1
    c.end 5
    c.obj 'Protein'
    c.project_id {|denotaton| 
      if denotaton.project.present?
        denotaton.association(:project)
      else
        1
      end
    }
    c.doc_id {|denotation| 
      if denotation.doc.present?
        denotation.association(:doc)
      else
        1
      end
    }
    c.created_at 1.hour.ago
    c.updated_at 1.hour.ago
  end
end
