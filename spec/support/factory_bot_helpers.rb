module FactoryBotHelpers
  extend FactoryBot::Syntax::Methods

  # Create annotations for a document
  # @param doc [Doc] The document to annotate
  # @param accessibility [Integer] The accessibility level for the project
  def self.create_annotations_for_doc(doc, accessibility:)
    project = create(:project, accessibility: accessibility)
    doc.project_docs.create(project: project)

    denotation1 = create(:denotation, doc: doc, project: project)
    denotation2 = create(:object_denotation, doc: doc, project: project)
    create_relations_and_attributes_for_doc(doc, project, denotation1, denotation2)
  end

  # Create relations and attributes for a document
  # @param doc [Doc] The document
  # @param project [Project] The project
  # @param denotation1 [Denotation] The first denotation
  # @param denotation2 [Denotation] The second denotation
  def self.create_relations_and_attributes_for_doc(doc, project, denotation1, denotation2)
    create(:relation, project: project, doc: doc, hid: "R1", subj: denotation1, obj: denotation2, pred: 'predicate')
    create(:attrivute, project: project, doc: doc, hid: "A1", subj: denotation1, obj: 'Protein', pred: 'type')

    block1 = create(:block, doc: doc, project: project)
    block2 = create(:second_block, doc: doc, project: project)
    create(:relation, project: project, doc: doc, hid: "S1", subj: block1, obj: block2, pred: 'next')
    create(:attrivute, project: project, doc: doc, hid: "A2", subj: block1, obj: 'true', pred: 'suspect')
  end
end