# frozen_string_literal: true

FactoryBot.define do
  factory :project_doc do
    association :project
    association :doc

    denotations_num { 0 }
    blocks_num { 0 }
    relations_num { 0 }

    after(:create) do |project_doc|
      Doc.increment_counter(:projects_num, project_doc.doc_id)
    end
  end
end
