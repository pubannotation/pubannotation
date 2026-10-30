# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'factory' do
    it 'creates a valid doc' do
      doc = create(:doc)
      expect(doc).to be_persisted
      expect(doc.sourcedb).to be_present
      expect(doc.sourceid).to be_present
      expect(doc.body).to be_present
    end
  end

  describe 'validations' do
    it 'requires sourcedb and sourceid' do
      doc = Doc.new
      expect(doc).not_to be_valid
    end
  end

  describe 'line endings' do
    it 'stores the line breaks of a new body as LF' do
      doc = create(:doc, body: "Hello\r\nworld")

      expect(doc.reload.body).to eq("Hello\nworld")
    end

    it 'stores the line breaks of a changed body as LF' do
      doc = create(:doc, body: 'Hello world')

      doc.update!(body: "Hello\r\nthere")

      expect(doc.reload.body).to eq("Hello\nthere")
    end
  end

  describe 'relation counts with span' do
    let(:project) { create(:project) }
    let(:doc) { create(:doc) }
    let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

    # Denotations at known positions
    let!(:d_0_5)   { create(:denotation, project: project, doc: doc, hid: 'T1', begin: 0,   end: 5) }
    let!(:d_10_20) { create(:denotation, project: project, doc: doc, hid: 'T2', begin: 10,  end: 20) }
    let!(:d_30_40) { create(:denotation, project: project, doc: doc, hid: 'T3', begin: 30,  end: 40) }
    let!(:d_90_100){ create(:denotation, project: project, doc: doc, hid: 'T4', begin: 90,  end: 100) }

    # Relations
    let!(:r_inside) {
      create(:relation, project: project, doc: doc, hid: 'R1',
             subj_type: 'Denotation', subj_id: d_0_5.id,
             obj_type: 'Denotation', obj_id: d_10_20.id)
    }
    let!(:r_straddle) {
      # subj inside [0,50], obj outside
      create(:relation, project: project, doc: doc, hid: 'R2',
             subj_type: 'Denotation', subj_id: d_10_20.id,
             obj_type: 'Denotation', obj_id: d_90_100.id)
    }
    let!(:r_outside) {
      create(:relation, project: project, doc: doc, hid: 'R3',
             subj_type: 'Denotation', subj_id: d_90_100.id,
             obj_type: 'Denotation', obj_id: d_90_100.id)
    }

    it 'returns 0 when no relations fall within the span' do
      expect(project.get_relations_count(doc, begin: 50, end: 60)).to eq(0)
    end

    it 'counts only relations whose subj and obj are fully inside the span' do
      expect(project.get_relations_count(doc, begin: 0, end: 50)).to eq(1)
    end

    it 'excludes relations that straddle the span boundary' do
      # [0,25] contains r_inside but not r_straddle (obj at 90-100) nor r_outside
      expect(project.get_relations_count(doc, begin: 0, end: 25)).to eq(1)
    end

    it 'includes all relations when the span covers the whole doc' do
      expect(project.get_relations_count(doc, begin: 0, end: 1000)).to eq(3)
    end

    it 'is inclusive at the span boundaries' do
      # r_inside uses d_0_5 (begin=0) and d_10_20 (end=20).
      # A span exactly matching those bounds must include it.
      expect(project.get_relations_count(doc, begin: 0, end: 20)).to eq(1)

      # Shrinking by one in either direction must drop it.
      expect(project.get_relations_count(doc, begin: 1, end: 20)).to eq(0)
      expect(project.get_relations_count(doc, begin: 0, end: 19)).to eq(0)
    end

    it 'excludes relations whose subj or obj is not a Denotation' do
      # The JOIN narrows to subj_type='Denotation' AND obj_type='Denotation'.
      # Block-typed endpoints are intentionally out of scope for this count,
      # matching the domain definition of Relation (denotation-to-denotation).
      block = create(:block, project: project, doc: doc, hid: 'B1', begin: 0, end: 5)
      create(:relation, project: project, doc: doc, hid: 'R4',
             subj_type: 'Block', subj_id: block.id,
             obj_type: 'Denotation', obj_id: d_10_20.id)

      # Count for [0, 50] is unchanged — only r_inside still qualifies.
      expect(project.get_relations_count(doc, begin: 0, end: 50)).to eq(1)
    end

    context 'when the doc is shared by multiple projects' do
      let(:other_project) { create(:project) }
      let!(:other_project_doc) { create(:project_doc, project: other_project, doc: doc) }
      let!(:other_d_0_5)   { create(:denotation, project: other_project, doc: doc, hid: 'T1', begin: 0,  end: 5) }
      let!(:other_d_10_20) { create(:denotation, project: other_project, doc: doc, hid: 'T2', begin: 10, end: 20) }
      let!(:other_r_inside) {
        create(:relation, project: other_project, doc: doc, hid: 'R1',
               subj_type: 'Denotation', subj_id: other_d_0_5.id,
               obj_type: 'Denotation', obj_id: other_d_10_20.id)
      }

      it 'scopes the count to the given project' do
        # Only r_inside belongs to `project` in [0,50].
        expect(project.get_relations_count(doc, begin: 0, end: 50)).to eq(1)
        # Only other_r_inside belongs to `other_project` in [0,50].
        expect(other_project.get_relations_count(doc, begin: 0, end: 50)).to eq(1)
      end

      it 'counts across all projects when project_id is nil' do
        # Both projects contribute one in-span relation each.
        expect(Relation.in_doc(doc.id).with_denotations_in_span({ begin: 0, end: 50 }).count).to eq(2)
      end
    end

    it 'runs as a single SQL query (no N+1)' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/
      end

      project.get_relations_count(doc, begin: 0, end: 1000)

      ActiveSupport::Notifications.unsubscribe(subscriber)
      expect(queries.size).to eq(1)
      expect(queries.first).to match(/COUNT/i)
      expect(queries.first).to match(/JOIN.*denotations/i)
    end
  end
end
