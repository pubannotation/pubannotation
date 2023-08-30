require 'rails_helper'

RSpec.describe InstantiateAndSaveAnnotationsCollection, type: :model do
  fixtures :project_docs

  before do
    @project = projects(:one)
    travel_to current do
      InstantiateAndSaveAnnotationsCollection.call @project, annotations_collection
    end
    @project.reload
  end

  describe "update to empty annotations" do
    let(:current) { Time.zone.local(2022, 7, 11, 10, 04, 44) }
    let(:annotations_collection) { [] }

    it "sets all annotation counts to 0 and updates timestamps" do
      expect(@project.denotations_num).to eq(0)
      expect(@project.relations_num).to eq(0)
      expect(@project.modifications_num).to eq(0)
      expect(@project.updated_at).to eq(current)
      expect(@project.annotations_updated_at).to eq(current)
    end

    it "does not create any annotations" do
      expect(Denotation.exists?).to be_falsey
      expect(Relation.exists?).to be_falsey
      expect(Attrivute.exists?).to be_falsey
      expect(Modification.exists?).to be_falsey
    end
  end

  describe "update to non-empty annotations" do
    let(:current) { Time.zone.local(2022, 7, 11, 10, 04, 44) }
    let(:annotations_collection) do
      [{ sourcedb: "test_db", sourceid: "1234",
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
         ],
         modifications: [
           { id: "m1", pred: "F", obj: "d1" },
           { id: "m2", pred: "G", obj: "d1" }
         ]
       }]
    end

    before do
      travel_to current do
        InstantiateAndSaveAnnotationsCollection.call @project, []
      end
    end

    it "sets all annotation counts to 0 and updates timestamps" do
      expect(@project.denotations_num).to eq(2)
      expect(@project.relations_num).to eq(2)
      expect(@project.modifications_num).to eq(2)
      expect(@project.project_docs.first.denotations_num).to eq(2)
      expect(@project.project_docs.first.relations_num).to eq(2)
      expect(@project.project_docs.first.modifications_num).to eq(2)
      expect(@project.updated_at).to eq(current)
      expect(@project.annotations_updated_at).to eq(current)
      expect(@project.project_docs.first.annotations_updated_at).to eq(current)
    end

    it 'creates annotations' do
      expect(Denotation.first.hid).to eq('d1')
      expect(Denotation.first.begin).to eq(1)
      expect(Denotation.first.end).to eq(2)
      expect(Denotation.first.obj).to eq('A')
      expect(Denotation.second.hid).to eq('d2')
      expect(Relation.first.hid).to eq('r1')
      expect(Relation.first.pred).to eq('C')
      expect(Relation.first.subj).to eq(Denotation.first)
      expect(Relation.first.obj).to eq(Denotation.second)
      expect(Relation.second.hid).to eq('r2')
      expect(Attrivute.first.hid).to eq('a1')
      expect(Attrivute.first.pred).to eq('D')
      expect(Attrivute.first.obj).to eq('E')
      expect(Attrivute.first.subj).to eq(Denotation.first)
      expect(Attrivute.second.hid).to eq('a2')
      expect(Modification.first.hid).to eq('m1')
      expect(Modification.first.pred).to eq('F')
      expect(Modification.first.obj).to eq(Denotation.first)
      expect(Modification.second.hid).to eq('m2')
    end
  end
end
