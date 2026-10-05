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

  describe 'shifting and finding denotations' do
    let(:doc) { create(:doc, body: 'Hello big world') }
    let(:project_a) { create(:project, annotations_updated_at: 1.day.ago).tap { it.add_doc!(doc) } }
    let(:project_b) { create(:project, annotations_updated_at: 1.day.ago).tap { it.add_doc!(doc) } }
    let!(:hello) { create(:denotation, project: project_a, doc:, begin: 0, end: 5) }
    let!(:world) { create(:denotation, project: project_b, doc:, begin: 10, end: 15) }
    let!(:big_world) { create(:denotation, project: project_b, doc:, begin: 6, end: 15) }

    before { ProjectDoc.where(doc:).update_all(annotations_updated_at: 1.day.ago) }

    def spans
      [hello, world, big_world].map { it.reload.attributes.values_at('id', 'begin', 'end') }
    end

    def timestamps(project)
      [project.reload.annotations_updated_at, ProjectDoc.find_by(project:, doc:).annotations_updated_at]
    end

    describe '#shift_denotations' do
      it 'moves the positions at or after the position by delta, in every project, keeping the denotations' do
        doc.shift_denotations(5, -2)

        expect(spans).to eq([[hello.id, 0, 3], [world.id, 8, 13], [big_world.id, 4, 13]])
      end

      it "advances the annotations_updated_at of the projects whose denotations moved, and their docs'" do
        before_a = timestamps(project_a)

        doc.shift_denotations(9, 1)

        expect(timestamps(project_b)).to all(be_within(1.minute).of(Time.current))
        expect(timestamps(project_a)).to eq(before_a)
      end

      it 'does nothing for a delta of zero' do
        before_b = timestamps(project_b)

        doc.shift_denotations(0, 0)

        expect(spans).to eq([[hello.id, 0, 5], [world.id, 10, 15], [big_world.id, 6, 15]])
        expect(timestamps(project_b)).to eq(before_b)
      end
    end

    describe '#denotations_within' do
      it 'finds the denotations within a span' do
        expect(doc.denotations_within(6, 15)).to contain_exactly(world, big_world)
      end
    end
  end

  describe '#speech_segment_spans' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello big world', medium:) }

    before do
      MediaTranscript.create!(medium:, doc:, segments: [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'big', 'start_ms' => 300, 'end_ms' => 600 },
        { 'text' => 'world', 'start_ms' => 600, 'end_ms' => 900 }
      ])
    end

    it "returns media_transcript's spans as-is when they fit the body" do
      expect(doc.speech_segment_spans).to eq([
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 9, start_ms: 300 },
        { begin: 10, end: 15, start_ms: 600 }
      ])
    end

    it 'drops spans past a body shortened after transcription and cuts the one running past its end' do
      doc.update_column(:body, 'Hello bi')

      expect(doc.speech_segment_spans).to eq([
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 8, start_ms: 300 }
      ])
    end

    it 'is empty without a media_transcript' do
      expect(create(:doc).speech_segment_spans).to eq([])
    end
  end
end
