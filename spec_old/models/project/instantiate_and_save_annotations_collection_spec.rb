require 'rails_helper'

RSpec.describe Project, type: :model do
  describe '#instantiate_and_save_annotations_collection' do
    let(:project_doc) { create(:project_doc) }
    let(:project) { project_doc.project }
    let(:doc) { project_doc.doc }

    let(:invoke_service) do
      travel_to current do
        project.instantiate_and_save_annotations_collection annotations_collection
      end
      project.reload
    end

    describe "update to empty annotations" do
      let(:current) { Time.zone.local(2022, 7, 11, 10, 04, 44) }
      let(:annotations_collection) { [] }

      before { invoke_service }

      it "resets annotations and updates timestamps" do
        expect(project).to have_attributes(
                             denotations_num: 0,
                             relations_num: 0,
                             updated_at: current,
                             annotations_updated_at: current
                           )
      end

      it "does not create any annotations" do
        expect(project.denotations.exists?).to be_falsey
        expect(project.relations.exists?).to be_falsey
        expect(project.attrivutes.exists?).to be_falsey
      end
    end

    describe "update to non-empty annotations" do
      let(:current) { Time.zone.local(2022, 7, 11, 10, 04, 44) }
      let(:annotations_collection) do
        [{ sourcedb: "PubMed", sourceid: doc.sourceid,
           denotations: [
             { id: "d1", span: { begin: 1, end: 2 }, obj: "A" },
             { id: "d2", span: { begin: 100, end: 200 }, obj: "B" }
           ],
           relations: [
             { id: "r1", pred: "C", subj: "d1", obj: "d2" },
             { id: "r2", pred: "C", subj: "d2", obj: "d1" }
           ],
           attributes: [
             { id: "a1", pred: "D", obj: "E", subj: "d1" },
             { id: "a2", pred: "D", obj: "E", subj: "d2" }
           ]
         }]
      end

      before { invoke_service }

      it "updates annotations and timestamps" do
        expect(project).to have_attributes(
                             denotations_num: 2,
                             relations_num: 2,
                             updated_at: current,
                             annotations_updated_at: current
                           )

        expect(project.project_docs.first).to have_attributes(
                                                denotations_num: 2,
                                                relations_num: 2,
                                                annotations_updated_at: current
                                              )
      end

      it 'creates annotations' do
        denotation1 = Denotation.find_by(hid: 'd1')
        denotation2 = Denotation.find_by(hid: 'd2')

        expect(denotation1).to have_attributes(begin: 1, end: 2, obj: 'A')
        expect(denotation2).to have_attributes(begin: 100, end: 200, obj: 'B')

        relation1 = Relation.find_by(hid: 'r1')
        relation2 = Relation.find_by(hid: 'r2')

        expect(relation1).to have_attributes(pred: 'C', subj: denotation1, obj: denotation2)
        expect(relation2).to have_attributes(pred: 'C', subj: denotation2, obj: denotation1)

        attribute1 = Attrivute.find_by(hid: 'a1')
        attribute2 = Attrivute.find_by(hid: 'a2')

        expect(attribute1).to have_attributes(pred: 'D', obj: 'E', subj: denotation1)
        expect(attribute2).to have_attributes(pred: 'D', obj: 'E', subj: denotation2)
      end
    end

    describe "update to multi sourceid annotations" do
      let(:doc2) { create(:doc) }
      let!(:project_doc2) { create(:project_doc, project: project, doc: doc2) }

      let(:current) { Time.zone.local(2022, 7, 11, 10, 04, 44) }
      let(:annotations_collection) do
        [{ sourcedb: "PubMed", sourceid: doc.sourceid,
           denotations: [
             { id: "d1", span: { begin: 1, end: 2 }, obj: "A" }
           ]
          },
          { sourcedb: "PubMed", sourceid: doc2.sourceid,
            denotations: [
              { id: "d2", span: { begin: 100, end: 200 }, obj: "B" }
            ]
          }]
      end

      before { invoke_service }

      it "updates annotations and timestamps" do
        expect(project).to have_attributes(
                             denotations_num: 2,
                             relations_num: 0,
                             updated_at: current,
                             annotations_updated_at: current
                           )

        expect(project.project_docs.first).to have_attributes(
                                                denotations_num: 1,
                                                relations_num: 0,
                                                annotations_updated_at: current
                                              )

        expect(project.project_docs.second).to have_attributes(
                                                denotations_num: 1,
                                                relations_num: 0,
                                                annotations_updated_at: current
                                              )
      end
    end
  end
end