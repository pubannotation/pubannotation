# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaTranscript, type: :model do
  describe '.create_from_doc!' do
    def medium_with_file(media_type, content_type, fixture)
      create(:medium, media_type:, content_type:).tap do |medium|
        medium.file.attach(io: File.open(Rails.root.join('spec', 'fixtures', 'files', fixture)), filename: fixture, content_type:)
      end
    end

    before { allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98)) }

    { audio: ['audio/mpeg', 'test_audio.mp3'], video: ['video/mp4', 'test_video.mp4'] }.each do |media_type, (content_type, fixture)|
      it "gives a doc with #{media_type} a transcript with its body as one segment spanning the media's duration" do
        medium = medium_with_file(media_type, content_type, fixture)
        doc = create(:doc, body: 'Hello world', medium:)

        media_transcript = described_class.create_from_doc!(doc)

        expect(media_transcript).to be_persisted
        expect(doc.reload.media_transcript).to eq(media_transcript)
        expect(media_transcript.medium).to eq(medium)
        expect(media_transcript.text).to eq('Hello world')
        expect(media_transcript.segments).to match([have_attributes(text: 'Hello world', start_ms: 0, end_ms: 4_980)])
      end
    end

    it 'raises for a doc with an image' do
      doc = create(:doc, body: 'A caption.', medium: medium_with_file(:image, 'image/png', 'test_image.png'))

      expect { described_class.create_from_doc!(doc) }.to raise_error(ArgumentError, /can't get a transcript/)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:media_transcript)).to be_valid
    end

    it 'requires a medium' do
      expect(build(:media_transcript, medium: nil)).not_to be_valid
    end

    it 'does not require a media_transcription_task' do
      expect(build(:media_transcript)).to be_valid
    end

    it 'does not require a doc' do
      expect(build(:media_transcript, doc: nil)).to be_valid
    end

    it 'requires media_transcription_task_id to be unique when present' do
      task = create(:media_transcription_task)
      create(:media_transcript, media_transcription_task: task, medium: task.medium)

      expect(build(:media_transcript, media_transcription_task: task, medium: task.medium)).not_to be_valid
    end

    it 'allows multiple records with no media_transcription_task' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      create(:media_transcript, medium: medium)

      expect(build(:media_transcript, medium: medium)).to be_valid
    end

    it 'requires doc_id to be unique when present' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      create(:media_transcript, medium: medium, doc: doc)

      expect(build(:media_transcript, medium: medium, doc: doc)).not_to be_valid
    end

    it 'allows multiple records with no doc' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      create(:media_transcript, medium: medium, doc: nil)

      expect(build(:media_transcript, medium: medium, doc: nil)).to be_valid
    end

    it 'accepts a medium whose media_type is image' do
      medium = create(:medium, media_type: :image, content_type: 'image/jpeg')

      expect(build(:media_transcript, medium: medium, segments: [], text: 'A generated caption.')).to be_valid
    end

    it 'accepts a doc whose medium matches this transcript\'s medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)

      expect(build(:media_transcript, medium: medium, doc: doc)).to be_valid
    end

    it 'rejects a doc whose medium does not match this transcript\'s medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      other_medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: other_medium)

      expect(build(:media_transcript, medium: medium, doc: doc)).not_to be_valid
    end

    it 'rejects a doc with no medium at all' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: nil)

      expect(build(:media_transcript, medium: medium, doc: doc)).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      media_transcript = create(:media_transcript, medium: medium)

      expect(media_transcript.medium).to eq(medium)
    end

    it 'optionally belongs to a media_transcription_task' do
      task = create(:media_transcription_task)
      media_transcript = create(:media_transcript, media_transcription_task: task, medium: task.medium)

      expect(media_transcript.media_transcription_task).to eq(task)
    end

    it 'optionally belongs to a doc' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, medium: medium, doc: doc)

      expect(media_transcript.doc).to eq(doc)
    end
  end

  describe 'dependent behavior' do
    it 'is destroyed when its medium is destroyed' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      media_transcript = create(:media_transcript, medium: medium)

      medium.destroy

      expect(MediaTranscript.exists?(media_transcript.id)).to be false
    end

    it 'is not destroyed when its media_transcription_task is destroyed, but the reference is nullified' do
      task = create(:media_transcription_task)
      media_transcript = create(:media_transcript, media_transcription_task: task, medium: task.medium)

      task.destroy

      expect(media_transcript.reload.media_transcription_task_id).to be_nil
    end

    it 'is destroyed when its doc is destroyed' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, medium: medium, doc: doc)

      doc.destroy

      expect(MediaTranscript.exists?(media_transcript.id)).to be false
    end
  end

  describe '#speech_segments' do
    it 'includes all segments when every segment is spoken text' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ])

      expect(media_transcript.speech_segments).to eq(media_transcript.segments.to_a)
    end

    it 'excludes non-speech segments' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '(upbeat music)', start_ms: 0, end_ms: 3000)
      ])

      expect(media_transcript.speech_segments).to eq([])
    end

    it 'keeps only the spoken segments alongside non-speech segments' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '(upbeat music)', start_ms: 0, end_ms: 3000),
        build(:segment, :without_transcript, sort_order: 1, text: 'Welcome to the conference.', start_ms: 3000, end_ms: 6000)
      ])

      expect(media_transcript.speech_segments).to eq([media_transcript.segments.last])
    end

    it 'excludes segments with blank text' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '', start_ms: 0, end_ms: 300)
      ])

      expect(media_transcript.speech_segments).to eq([])
    end
  end

  describe '#segmented?' do
    it 'is true with segments' do
      expect(build(:media_transcript).segmented?).to be(true)
    end

    it 'is false with no segments, e.g. an image caption' do
      expect(build(:media_transcript, segments: []).segmented?).to be(false)
    end
  end

  describe '#line_break_settable_after?' do
    let(:media_transcript) do
      create(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: '(music)', start_ms: 300, end_ms: 600),
        build(:segment, :without_transcript, sort_order: 2, text: 'world', start_ms: 600, end_ms: 900),
        build(:segment, :without_transcript, sort_order: 3, text: '(applause)', start_ms: 900, end_ms: 1200)
      ])
    end

    it 'is true for a speech segment followed by another' do
      expect(media_transcript.line_break_settable_after?(media_transcript.segments[0])).to be(true)
    end

    it 'is false for a non-speech segment' do
      expect(media_transcript.line_break_settable_after?(media_transcript.segments[1])).to be(false)
    end

    it 'is false for the last speech segment, even with non-speech ones after it' do
      expect(media_transcript.line_break_settable_after?(media_transcript.segments[2])).to be(false)
    end
  end

  describe '#speech_text with line breaks' do
    it 'separates a speech segment from the next with a line break when one follows it' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: true),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600),
        build(:segment, :without_transcript, sort_order: 2, text: 'again', start_ms: 600, end_ms: 900)
      ])

      expect(media_transcript.speech_text).to eq("Hello\nworld again")
    end

    it 'takes the separator from the speech segment before a non-speech one, whose own is ignored' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: true),
        build(:segment, :without_transcript, sort_order: 1, text: '(music)', start_ms: 300, end_ms: 600),
        build(:segment, :without_transcript, sort_order: 2, text: 'world', start_ms: 600, end_ms: 900)
      ])

      expect(media_transcript.speech_text).to eq("Hello\nworld")
    end

    it 'leaves the spans where they are, a line break being one char as a space is' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: true),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ])

      expect(media_transcript.speech_segment_spans).to eq([
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 11, start_ms: 300 }
      ])
    end
  end

  describe '#speech_text' do
    it 'joins the text of only the speech segments' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '(upbeat music)', start_ms: 0, end_ms: 3000),
        build(:segment, :without_transcript, sort_order: 1, text: 'Welcome to the conference.', start_ms: 3000, end_ms: 6000)
      ])

      expect(media_transcript.speech_text).to eq('Welcome to the conference.')
    end

    it 'is blank when there are no speech segments' do
      media_transcript = build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: '(music)', start_ms: 0, end_ms: 100)])

      expect(media_transcript.speech_text).to eq('')
    end
  end

  describe '#speech_segment_spans' do
    it "returns each speech segment's char offset into #speech_text alongside its start_ms" do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ])

      expect(media_transcript.speech_segment_spans).to eq([
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 11, start_ms: 300 }
      ])
    end

    it 'excludes non-speech segments, without advancing the offset for later ones' do
      media_transcript = build(:media_transcript, segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '(upbeat music)', start_ms: 0, end_ms: 3000),
        build(:segment, :without_transcript, sort_order: 1, text: 'Welcome.', start_ms: 3000, end_ms: 6000)
      ])

      expect(media_transcript.speech_segment_spans).to eq([{ begin: 0, end: 8, start_ms: 3000 }])
    end

    it 'is empty when there are no speech segments' do
      media_transcript = build(:media_transcript, segments: [])

      expect(media_transcript.speech_segment_spans).to eq([])
    end
  end

  describe '#segment_pieces' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello big world', medium:) }
    let(:media_transcript) do
      create(:media_transcript, medium:, doc:, text: 'Hello big world', segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello big', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ])
    end
    let(:hello_big) { media_transcript.segments.first }
    let(:project_a) { create(:project) }
    let(:project_b) { create(:project) }

    def pieces_of(segment)
      media_transcript.segment_pieces(segment).map { [it.text, it.begin, it.end, it.denotations] }
    end

    it 'splits a segment at every denotation boundary, without the spaces around the pieces' do
      a = create(:denotation, project: project_a, doc:, begin: 0, end: 5)
      b = create(:denotation, project: project_b, doc:, begin: 6, end: 9)

      expect(pieces_of(hello_big)).to eq([['Hello', 0, 5, [a]], ['big', 6, 9, [b]]])
    end

    it 'makes more pieces of overlapping denotations' do
      a = create(:denotation, project: project_a, doc:, begin: 0, end: 9)
      b = create(:denotation, project: project_b, doc:, begin: 0, end: 5)

      expect(pieces_of(hello_big).map { [it[0], it[1], it[2], it[3].to_set] })
        .to eq([['Hello', 0, 5, Set[a, b]], ['big', 6, 9, Set[a]]])
    end

    it 'leaves out the pieces of spaces only' do
      create(:denotation, project: project_a, doc:, begin: 0, end: 5)
      create(:denotation, project: project_b, doc:, begin: 6, end: 9)

      expect(pieces_of(hello_big).map(&:first)).not_to include(' ', '')
    end

    it 'makes the text outside the denotations a piece of its own' do
      a = create(:denotation, project: project_a, doc:, begin: 0, end: 5)

      expect(pieces_of(hello_big)).to eq([['Hello', 0, 5, [a]], ['big', 6, 9, []]])
    end

    it 'gives no pieces to a segment with no denotations, or no speech' do
      create(:denotation, project: project_a, doc:, begin: 0, end: 5)
      music = media_transcript.segments.build(sort_order: 2, text: '(music)', start_ms: 600, end_ms: 700)

      expect(media_transcript.segment_pieces(media_transcript.segments.second)).to eq([])
      expect(media_transcript.segment_pieces(music)).to eq([])
    end

    it 'labels the denotations of projects the user cannot access as private' do
      private_project = create(:project, accessibility: 2)
      create(:denotation, project: private_project, doc:, begin: 0, end: 5, obj: 'Protein')
      create(:denotation, project: project_a, doc:, begin: 6, end: 9, obj: 'Gene')
      pieces = media_transcript.segment_pieces(hello_big)

      expect(pieces.map { it.labels(create(:user)) }).to eq([['(private project)'], ["#{project_a.name}: Gene"]])
      expect(pieces.first.labels(private_project.user)).to eq(["#{private_project.name}: Protein"])
    end

    it "labels the denotations of blind projects as private but to their owner, the project being accessible but not its annotations" do
      blind_project = create(:project, accessibility: 3)
      create(:denotation, project: blind_project, doc:, begin: 0, end: 5, obj: 'Protein')
      piece = media_transcript.segment_pieces(hello_big).first

      expect(piece.labels(create(:user))).to eq(['(private project)'])
      expect(piece.labels(nil)).to eq(['(private project)'])
      expect(piece.labels(blind_project.user)).to eq(["#{blind_project.name}: Protein"])
    end
  end

  describe '#create_segment_blocks!' do
    before { allow(Elasticsearch::IndexQueue).to receive(:index_doc) }

    it 'gives its doc, in the project, an AudioSegment block for each speech segment, counted once' do
      project = create(:project)
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, body: 'Hello world', medium:).tap { project.add_doc!(it) }
      media_transcript = create(:media_transcript, medium:, doc:, text: 'Hello world', segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: '(music)', start_ms: 300, end_ms: 600),
        build(:segment, :without_transcript, sort_order: 2, text: 'world', start_ms: 600, end_ms: 900)
      ])

      media_transcript.create_segment_blocks!(project)

      expect(doc.blocks.order(:hid).pluck(:project_id, :hid, :begin, :end, :obj))
        .to eq([[project.id, 'B1', 0, 5, 'AudioSegment'], [project.id, 'B2', 6, 11, 'AudioSegment']])
      expect(ProjectDoc.find_by(project:, doc:).blocks_num).to eq(2)
      expect(doc.reload.blocks_num).to eq(2)
      expect(project.reload.blocks_num).to eq(2)
    end

    it "advances the project's annotations_updated_at, for its exports to be updated, but not its doc's" do
      project = create(:project, annotations_updated_at: 1.day.ago)
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, body: 'Hello world', medium:).tap { project.add_doc!(it) }
      media_transcript = create(:media_transcript, medium:, doc:, text: 'Hello world')

      expect { media_transcript.create_segment_blocks!(project) }
        .to change { project.reload.annotations_updated_at }.to(be_within(1.minute).of(Time.current))
      expect(ProjectDoc.find_by(project:, doc:).annotations_updated_at).to be_nil
    end
  end

  describe 'rebuilding the AudioSegment blocks as the segments change' do
    before { allow(Elasticsearch::IndexQueue).to receive(:index_doc) }

    let(:project) { create(:project) }
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:).tap { project.add_doc!(it) } }
    let!(:media_transcript) do
      create(:media_transcript, medium:, doc:, text: 'Hello world').tap { it.create_segment_blocks!(project) }
    end

    def segment_blocks
      doc.blocks.where(obj: 'AudioSegment').order(:hid).pluck(:project_id, :hid, :begin, :end)
    end

    def blocks_nums
      [ProjectDoc.find_by(project:, doc:).blocks_num, doc.reload.blocks_num, project.reload.blocks_num]
    end

    it "spans the speech segments as a segment's text is edited" do
      media_transcript.update_segment!(media_transcript.segments.first, { text: 'Hi there' })

      expect(segment_blocks).to eq([[project.id, 'B1', 0, 8], [project.id, 'B2', 9, 14]])
      expect(blocks_nums).to eq([2, 2, 2])
    end

    it 'spans the speech segments as they are resegmented, counting them anew' do
      media_transcript.resegment!([
        { text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: false },
        { text: 'wo', start_ms: 300, end_ms: 450, line_break_after: false },
        { text: '(music)', start_ms: 450, end_ms: 500, line_break_after: false },
        { text: 'rld', start_ms: 500, end_ms: 600, line_break_after: false }
      ])

      expect(segment_blocks).to eq([[project.id, 'B1', 0, 5], [project.id, 'B2', 6, 8], [project.id, 'B3', 9, 12]])
      expect(blocks_nums).to eq([3, 3, 3])
    end

    it 'spans the speech segments as they are merged or split at a space, leaving the text as it is' do
      media_transcript.resegment!([{ text: 'Hello world', start_ms: 0, end_ms: 600, line_break_after: false }])

      expect(doc.reload.body).to eq('Hello world')
      expect(segment_blocks).to eq([[project.id, 'B1', 0, 11]])
      expect(blocks_nums).to eq([1, 1, 1])

      media_transcript.resegment!([
        { text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: false },
        { text: 'world', start_ms: 300, end_ms: 600, line_break_after: false }
      ])

      expect(doc.reload.body).to eq('Hello world')
      expect(segment_blocks).to eq([[project.id, 'B1', 0, 5], [project.id, 'B2', 6, 11]])
      expect(blocks_nums).to eq([2, 2, 2])
    end

    it 'spans the one segment the text is replaced with' do
      media_transcript.replace_text!('Hello there world')

      expect(segment_blocks).to eq([[project.id, 'B1', 0, 17]])
      expect(blocks_nums).to eq([1, 1, 1])
    end

    it "deletes the relations and attributes on the old blocks, uncounting the relations" do
      first, second = doc.blocks.order(:hid).to_a
      relation = create(:relation, project:, doc:, subj: first, obj: second)
      Attrivute.create!(project:, doc:, hid: 'A1', subj: first, obj: 'true', pred: 'checked')
      Attrivute.create!(project:, doc:, hid: 'A2', subj: relation, obj: 'true', pred: 'checked')

      media_transcript.update_segment!(media_transcript.segments.first, { text: 'Hi' })

      expect(Relation.where(doc:)).to be_empty
      expect(Attrivute.where(doc:)).to be_empty
      expect([ProjectDoc.find_by(project:, doc:).relations_num, doc.reload.relations_num, project.reload.relations_num])
        .to eq([0, 0, 0])
    end

    it "advances the project's annotations_updated_at, for its exports to be updated, but not its doc's" do
      project.update_columns(annotations_updated_at: 1.day.ago)

      expect { media_transcript.update_segment!(media_transcript.segments.first, { text: 'Hi' }) }
        .to change { project.reload.annotations_updated_at }.to(be_within(1.minute).of(Time.current))
      expect(ProjectDoc.find_by(project:, doc:).annotations_updated_at).to be_nil
    end

    it 'leaves the other blocks on the doc as they are' do
      other = create(:block, project:, doc:, hid: 'B10', obj: 'Other', begin: 0, end: 5)

      media_transcript.update_segment!(media_transcript.segments.first, { text: 'Hi' })

      expect(other.reload.attributes.values_at('begin', 'end', 'obj')).to eq([0, 5, 'Other'])
    end

    it 'gives none to a project the doc is in without them' do
      other_project = create(:project).tap { it.add_doc!(doc) }

      media_transcript.update_segment!(media_transcript.segments.first, { text: 'Hi' })

      expect(doc.blocks.where(project: other_project)).to be_empty
    end

    it 'leaves them, with the relations on them, as they are as only the separators change, keeping their spans' do
      block_ids = doc.blocks.ids
      first, second = doc.blocks.order(:hid).to_a
      relation = create(:relation, project:, doc:, subj: first, obj: second)

      media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: true })

      expect(doc.blocks.ids).to match_array(block_ids)
      expect(relation.reload).to be_present
    end
  end

  describe '#allows_doc_body?' do
    it 'accepts only the transcript text when transcribed by Whisper' do
      transcript = build(:media_transcript, generation_model: 'whisper:ggml-base.en', text: 'Hello world')

      expect(transcript.allows_doc_body?('Hello world')).to be(true)
      expect(transcript.allows_doc_body?('Changed body')).to be(false)
    end

    it 'accepts matching and changed text when not transcribed by Whisper' do
      transcript = build(:media_transcript, generation_model: nil, text: 'Hello world')

      expect(transcript.allows_doc_body?('Hello world')).to be(true)
      expect(transcript.allows_doc_body?('Changed body')).to be(true)
    end
  end

  describe '#transcribed_by_whisper?' do
    it 'is true for a Whisper model' do
      expect(build(:media_transcript, generation_model: 'whisper:ggml-base.en').transcribed_by_whisper?).to be(true)
    end

    it 'is false for another model, e.g. an image caption one' do
      expect(build(:media_transcript, generation_model: 'moondream').transcribed_by_whisper?).to be(false)
    end

    it 'is false with no model recorded' do
      expect(build(:media_transcript, generation_model: nil).transcribed_by_whisper?).to be(false)
    end
  end

  describe 'text' do
    it 'defaults to nil' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

      media_transcript = MediaTranscript.new(medium: medium)

      expect(media_transcript.text).to be_nil
    end

    it 'is derived from the speech segments of a new one' do
      expect(build(:media_transcript).text).to eq('Hello world')
    end

    it 'is derived blank from only non-speech segments, and is valid' do
      media_transcript = build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: '(music)', start_ms: 0, end_ms: 100)])

      expect(media_transcript.text).to eq('')
      expect(media_transcript).to be_valid
    end

    it 'is kept as given, e.g. an image caption' do
      expect(build(:media_transcript, text: 'A caption.', segments: []).text).to eq('A caption.')
    end

    it 'is required to be set, which it is not with no segments to derive it from' do
      media_transcript = build(:media_transcript, segments: [])

      expect(media_transcript).not_to be_valid
      expect(media_transcript.errors[:text]).to include("can't be nil")
    end

    it 'is valid with a value' do
      expect(build(:media_transcript, text: 'A generated caption.')).to be_valid
    end
  end

  describe 'segments' do
    it 'stores an array of timed text segments' do
      media_transcript = create(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: 0, end_ms: 100)])

      expect(media_transcript.reload.segments).to match([have_attributes(text: 'Hi', start_ms: 0, end_ms: 100)])
    end

    it 'defaults to an empty array' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

      media_transcript = MediaTranscript.new(medium: medium)

      expect(media_transcript.segments).to be_empty
    end

    it 'is valid with an empty array, e.g. for an image caption' do
      expect(build(:media_transcript, text: 'A caption.', segments: [])).to be_valid
    end

    it 'is valid when a segment has equal start_ms and end_ms' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: 100, end_ms: 100)])).to be_valid
    end

    it 'rejects a segment with no end_ms' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: 0, end_ms: nil)])).not_to be_valid
    end

    it 'rejects a segment with no text' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: nil, start_ms: 0, end_ms: 100)])).not_to be_valid
    end

    it 'rejects a segment with a negative start_ms' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: -1, end_ms: 100)])).not_to be_valid
    end

    it 'rejects a segment whose end_ms is not an integer' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: 0, end_ms: 100.0)])).not_to be_valid
    end

    it 'rejects a segment whose end_ms is before its start_ms' do
      expect(build(:media_transcript, segments: [build(:segment, :without_transcript, sort_order: 0, text: 'Hi', start_ms: 100, end_ms: 0)])).not_to be_valid
    end

    it 'rejects segments that are out of chronological order' do
      segments = [
        build(:segment, :without_transcript, sort_order: 0, text: 'world', start_ms: 300, end_ms: 600),
        build(:segment, :without_transcript, sort_order: 1, text: 'Hello', start_ms: 0, end_ms: 300)
      ]

      expect(build(:media_transcript, segments: segments)).not_to be_valid
    end

    it 'rejects overlapping segments' do
      segments = [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 100, end_ms: 400)
      ]

      expect(build(:media_transcript, segments: segments)).not_to be_valid
    end

    it 'allows a gap between segments' do
      segments = [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 500, end_ms: 800)
      ]

      expect(build(:media_transcript, segments: segments)).to be_valid
    end
  end

  describe '#set_segment_text' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

    it "replaces the segment's text, keeping its timing, once saved" do
      media_transcript.set_segment_text(media_transcript.segments.first, 'Goodbye')
      media_transcript.save!

      expect(media_transcript.reload.segments).to match([
        have_attributes(text: 'Goodbye', start_ms: 0, end_ms: 300),
        have_attributes(text: 'world', start_ms: 300, end_ms: 600)
      ])
    end

    it 'strips surrounding whitespace from the text' do
      media_transcript.set_segment_text(media_transcript.segments.first, "  Goodbye\n")

      expect(media_transcript.segments.first.text).to eq('Goodbye')
    end

    it "raises for a segment not among its own, e.g. another transcript's" do
      other_segment = create(:segment)

      expect { media_transcript.set_segment_text(other_segment, 'Goodbye') }
        .to raise_error(ActiveRecord::RecordNotFound, /No segment with id #{other_segment.id}/)
    end

    it 'raises for a segment since replaced, which leaves its id with none' do
      replaced = media_transcript.segments.first
      media_transcript.replace_segments([build(:segment, :without_transcript, sort_order: 0, text: 'Hello world', start_ms: 0, end_ms: 600)])
      media_transcript.save!

      expect { media_transcript.set_segment_text(replaced, 'Goodbye') }.to raise_error(ActiveRecord::RecordNotFound, /No segment with id/)
    end

    it 'raises for blank text' do
      expect { media_transcript.set_segment_text(media_transcript.segments.first, ' ') }.to raise_error(ArgumentError, /Text is missing/)
    end

    it 'raises for text that is empty once stripped, e.g. a null char' do
      expect { media_transcript.set_segment_text(media_transcript.segments.first, "\0") }.to raise_error(ArgumentError, /Text is missing/)
    end

    it 'raises for no text' do
      expect { media_transcript.set_segment_text(media_transcript.segments.first, nil) }.to raise_error(ArgumentError, /Text is missing/)
    end
  end

  describe 'moving the denotations as segment text is edited' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }
    let(:hello) { media_transcript.segments.first }
    let(:world) { media_transcript.segments.last }
    let!(:a) { create(:denotation, project: create(:project), doc:, begin: 0, end: 5) }
    let!(:b) { create(:denotation, project: create(:project), doc:, begin: 6, end: 11) }

    def span(denotation) = denotation.reload.attributes.values_at('begin', 'end')

    describe '#update_segment_piece!' do
      it 'replaces the piece, growing the denotation on it and shifting those after it' do
        ids = [a.id, b.id]

        media_transcript.update_segment_piece!(hello, 0, 5, 'Hello', 'Goodbye')

        expect(doc.reload.body).to eq('Goodbye world')
        expect([span(a), span(b)]).to eq([[0, 7], [8, 13]])
        expect(Denotation.where(doc:).ids).to match_array(ids)
      end

      it 'normalizes the new text of the piece' do
        media_transcript.update_segment_piece!(hello, 0, 5, 'Hello', '  Good   bye ')

        expect(doc.reload.body).to eq('Good bye world')
        expect(span(a)).to eq([0, 8])
      end

      it 'rejects a blank piece, changing nothing' do
        expect { media_transcript.update_segment_piece!(hello, 0, 5, 'Hello', ' ') }
          .to raise_error(ArgumentError, 'Text is missing.')
        expect(doc.reload.body).to eq('Hello world')
        expect([span(a), span(b)]).to eq([[0, 5], [6, 11]])
      end

      it 'rejects a piece edited into a non-speech label, which would take the segment out of the body' do
        expect { media_transcript.update_segment_piece!(hello, 0, 5, 'Hello', '(music)') }
          .to raise_error(ArgumentError, "A segment with denotations on it can't become a non-speech label.")
        expect(doc.reload.body).to eq('Hello world')
        expect([span(a), span(b)]).to eq([[0, 5], [6, 11]])
      end

      it 'rejects a range that is no longer a piece, e.g. split by a denotation added since the page was loaded' do
        create(:denotation, project: create(:project), doc:, begin: 0, end: 3)

        expect { media_transcript.update_segment_piece!(hello, 0, 5, 'Hello', 'Goodbye') }
          .to raise_error(ArgumentError, /The segment has changed since the page was loaded/)
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'rejects a range that is not a piece, e.g. counted from the end' do
        expect { media_transcript.update_segment_piece!(hello, -3, -1, 'll', 'xx') }
          .to raise_error(ArgumentError, /The segment has changed since the page was loaded/)
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'rejects a piece from a stale page, changing nothing' do
        expect { media_transcript.update_segment_piece!(hello, 0, 5, 'Hallo', 'Goodbye') }
          .to raise_error(ArgumentError, 'The segment has changed since the page was loaded. Reload it and try again.')
        expect(doc.reload.body).to eq('Hello world')
        expect([span(a), span(b)]).to eq([[0, 5], [6, 11]])
      end
    end

    describe '#update_segment! with text' do
      it 'shifts the denotations after a segment with none, as its whole text is edited' do
        a.destroy

        media_transcript.update_segment!(hello, { text: 'Hi' })

        expect(doc.reload.body).to eq('Hi world')
        expect(span(b)).to eq([3, 8])
      end

      it 'refuses the whole text of a segment with denotations' do
        expect { media_transcript.update_segment!(hello, { text: 'Hi' }) }
          .to raise_error(ArgumentError, "A segment with denotations on it can't be edited as a whole.")
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'shifts the denotations after a speech segment edited into a label' do
        a.destroy

        media_transcript.update_segment!(hello, { text: '(music)' })

        expect(doc.reload.body).to eq('world')
        expect(span(b)).to eq([0, 5])
      end
    end

    it 'shifts the denotations after a non-speech segment edited into speech, separator included' do
      music_doc = create(:doc, body: 'world', medium:)
      transcript = create(:media_transcript, medium:, doc: music_doc, text: 'world', segments: [
        build(:segment, :without_transcript, sort_order: 0, text: '(music)', start_ms: 0, end_ms: 300),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ])
      world_denotation = create(:denotation, project: create(:project), doc: music_doc, begin: 0, end: 5)

      transcript.update_segment!(transcript.segments.first, { text: 'Hello' })

      expect(music_doc.reload.body).to eq('Hello world')
      expect(span(world_denotation)).to eq([6, 11])
    end
  end

  describe '#update_segment!' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

    it "saves the segment's text, rebuilding the text and the doc's body" do
      media_transcript.update_segment!(media_transcript.segments.last, { text: 'there' })

      expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello there])
      expect(doc.reload.body).to eq('Hello there')
    end

    it "saves whether a line break follows the segment, rebuilding the text and the doc's body" do
      media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: true })

      expect(media_transcript.reload.segments.first.line_break_after).to be(true)
      expect(doc.reload.body).to eq("Hello\nworld")
    end

    it 'locks itself while changing the segment' do
      expect(media_transcript).to receive(:with_lock).and_call_original

      media_transcript.update_segment!(media_transcript.segments.last, { text: 'there' })
    end

    it 'saves nothing when the change is rejected' do
      expect { media_transcript.update_segment!(media_transcript.segments.last, { text: ' ' }) }
        .to raise_error(ArgumentError, 'Text is missing.')
      expect(doc.reload.body).to eq('Hello world')
    end
  end

  describe '#resegment!' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

    it "replaces all the segments, numbered in order, and rebuilds the text and the doc's body" do
      old_ids = media_transcript.segments.map(&:id)

      media_transcript.resegment!([
        { text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: false },
        { text: 'wo', start_ms: 300, end_ms: 450, line_break_after: false },
        { text: 'rld', start_ms: 450, end_ms: 600, line_break_after: false }
      ])

      expect(media_transcript.reload.segments).to match([
        have_attributes(sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        have_attributes(sort_order: 1, text: 'wo', start_ms: 300, end_ms: 450),
        have_attributes(sort_order: 2, text: 'rld', start_ms: 450, end_ms: 600)
      ])
      expect(media_transcript.segments.map(&:id)).not_to include(*old_ids)
      expect(doc.reload.body).to eq('Hello wo rld')
    end

    it 'takes only the text, the times, and the line break of each' do
      media_transcript.resegment!([{ text: 'Hello world', start_ms: 0, end_ms: 600, line_break_after: false,
                                     sort_order: 5, media_transcript_id: 0 }])

      expect(media_transcript.reload.segments).to match([have_attributes(sort_order: 0, text: 'Hello world')])
    end

    it 'locks itself while replacing the segments' do
      expect(media_transcript).to receive(:with_lock).and_call_original

      media_transcript.resegment!([{ text: 'Hello world', start_ms: 0, end_ms: 600, line_break_after: false }])
    end

    it 'saves none of them when one is invalid' do
      expect do
        media_transcript.resegment!([
          { text: 'Hello', start_ms: 0, end_ms: 400, line_break_after: false },
          { text: 'world', start_ms: 300, end_ms: 600, line_break_after: false }
        ])
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello world])
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'saves none of them when they start or end at another time than the segments they replace' do
      [[{ text: 'Hello', start_ms: 100, end_ms: 300 }, { text: 'world', start_ms: 300, end_ms: 600 }],
       [{ text: 'Hello', start_ms: 0, end_ms: 300 }, { text: 'world', start_ms: 300, end_ms: 500 }],
       [{ text: 'Hello', start_ms: 0, end_ms: 300 }, { text: 'world', start_ms: 300, end_ms: 700 }]].each do |segments|
        expect do
          media_transcript.resegment!(segments.map { it.merge(line_break_after: false) })
        end.to raise_error(ActiveRecord::RecordInvalid, /Segments must span the same time as before, 0 to 600 ms/)
        expect(media_transcript.reload.segments.map { [it.start_ms, it.end_ms] }).to eq([[0, 300], [300, 600]])
      end
    end

    it 'saves them when they span the same time, even with a gap between them' do
      media_transcript.resegment!([
        { text: 'Hello', start_ms: 0, end_ms: 200, line_break_after: false },
        { text: 'world', start_ms: 400, end_ms: 600, line_break_after: false }
      ])

      expect(media_transcript.reload.segments.map { [it.start_ms, it.end_ms] }).to eq([[0, 200], [400, 600]])
    end
  end

  describe '#replace_text!' do
    it 'merges the segments into one spanning them all' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, body: 'Hello world', medium:)
      media_transcript = create(:media_transcript, medium:, doc:, text: 'Hello world', segments: [
        build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 400),
        build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 500, end_ms: 1000)
      ])

      media_transcript.replace_text!('Goodbye world')

      expect(media_transcript.reload.segments).to match([have_attributes(text: 'Goodbye world', start_ms: 0, end_ms: 1000)])
      expect(media_transcript.text).to eq('Goodbye world')
    end

    it 'replaces just the text with no segments, e.g. an image caption' do
      medium = create(:medium, media_type: :image, content_type: 'image/png')
      media_transcript = create(:media_transcript, medium:, text: 'A caption.', segments: [])

      media_transcript.replace_text!('Another caption.')

      expect(media_transcript.reload.text).to eq('Another caption.')
      expect(media_transcript.segments).to be_empty
    end
  end

  describe 'following changed segments' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

    it "puts a line break set after a segment into the text and the doc's body, keeping the segments apart" do
      media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: true })

      media_transcript.reload
      expect(media_transcript.text).to eq("Hello\nworld")
      expect(doc.reload.body).to eq("Hello\nworld")
      expect(media_transcript.segments.map(&:line_break_after)).to eq([true, false])
    end

    it 'puts a space back when the line break is unset' do
      media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: true })
      media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: false })

      expect(doc.reload.body).to eq('Hello world')
    end

    it "raises for a segment not among its own, e.g. another transcript's" do
      other_segment = create(:segment)

      expect { media_transcript.update_segment!(other_segment, { line_break_after: true }) }
        .to raise_error(ActiveRecord::RecordNotFound, /No segment with id #{other_segment.id}/)
    end

    it 'raises for a segment no line break can follow, e.g. the last one, leaving it unchanged' do
      expect { media_transcript.update_segment!(media_transcript.segments.last, { line_break_after: true }) }
        .to raise_error(ArgumentError, 'No line break can follow this segment.')
      expect(media_transcript.segments.last).not_to be_changed
    end

    context 'transcribed by Whisper, with a line break set after a segment' do
      let!(:media_transcript) do
        create(:media_transcript, medium:, doc:, text: 'Hello world', generation_model: 'whisper:ggml-base.en')
      end

      it "puts it into the doc's body, which is locked against other edits" do
        media_transcript.update_segment!(media_transcript.segments.first, { line_break_after: true })

        expect(doc.reload.body).to eq("Hello\nworld")
      end
    end

    it "rebuilds the text and the doc's body from the segments" do
      media_transcript.set_segment_text(media_transcript.segments.last, 'there')
      media_transcript.save!

      expect(media_transcript.reload.text).to eq('Hello there')
      expect(doc.reload.body).to eq('Hello there')
    end

    context 'transcribed by Whisper' do
      let!(:media_transcript) do
        create(:media_transcript, medium:, doc:, text: 'Hello world', generation_model: 'whisper:ggml-base.en')
      end

      it "still rebuilds the doc's body, which is locked against other edits, keeping the segments apart" do
        media_transcript.set_segment_text(media_transcript.segments.last, 'there')
        media_transcript.save!

        expect(doc.reload.body).to eq('Hello there')
        expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello there])
      end
    end

    it 'refuses segments left with no speech, as the body would be left with none' do
      media_transcript.set_segment_text(media_transcript.segments.first, '(music)')
      media_transcript.set_segment_text(media_transcript.segments.last, '(applause)')

      expect { media_transcript.save! }
        .to raise_error(ActiveRecord::RecordInvalid, /Segments must have speech for the transcript of a document/)
      expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello world])
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'refuses changed segments for a transcript with no doc' do
      orphan = create(:media_transcript, medium:)
      orphan.set_segment_text(orphan.segments.first, 'Goodbye')

      expect { orphan.save! }.to raise_error(ActiveRecord::RecordInvalid, /can't be changed for a transcript with no document/)
      expect(orphan.reload.segments.first.text).to eq('Hello')
    end

    it 'rolls back the transcript when the doc fails to save' do
      allow(media_transcript.doc).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      media_transcript.set_segment_text(media_transcript.segments.first, 'Goodbye')

      expect { media_transcript.save! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(media_transcript.reload.segments.first.text).to eq('Hello')
      expect(media_transcript.text).to eq('Hello world')
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'leaves the doc alone when the segments are unchanged' do
      expect { media_transcript.update!(updated_at: 1.minute.from_now) }.not_to(change { doc.reload.updated_at })
    end
  end
end
