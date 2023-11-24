FactoryBot.define do
  factory :doc do
    sourcedb { "PubMed" }
    sequence(:sourceid, &:to_s)
    body { "This is a test.\nTests are implemented.\nImplementation is difficult." }

    trait :with_annotation do
      after(:create) do |doc, _|
        FactoryBotHelpers.create_annotations_for_doc(doc, accessibility: 1)
      end
    end

    trait :with_private_annotation do
      after(:create) do |doc, _|
        FactoryBotHelpers.create_annotations_for_doc(doc, accessibility: 0)

        # Create an accessible project without annotations
        project2 = create(:project, accessibility: 1)
        doc.project_docs.create(project: project2)
      end
    end
  end
end
