# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaTranscript, type: :model do
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
      media_transcript.set_segment_line_break_after(media_transcript.segments.first, true)
      media_transcript.save!

      media_transcript.reload
      expect(media_transcript.text).to eq("Hello\nworld")
      expect(doc.reload.body).to eq("Hello\nworld")
      expect(media_transcript.segments.map(&:line_break_after)).to eq([true, false])
    end

    it 'puts a space back when the line break is unset' do
      media_transcript.set_segment_line_break_after(media_transcript.segments.first, true)
      media_transcript.save!
      media_transcript.set_segment_line_break_after(media_transcript.segments.first, false)
      media_transcript.save!

      expect(doc.reload.body).to eq('Hello world')
    end

    it "raises for a segment not among its own, e.g. another transcript's" do
      other_segment = create(:segment)

      expect { media_transcript.set_segment_line_break_after(other_segment, true) }
        .to raise_error(ActiveRecord::RecordNotFound, /No segment with id #{other_segment.id}/)
    end

    context 'transcribed by Whisper, with a line break set after a segment' do
      let!(:media_transcript) do
        create(:media_transcript, medium:, doc:, text: 'Hello world', generation_model: 'whisper:ggml-base.en')
      end

      it "puts it into the doc's body, which is locked against other edits" do
        media_transcript.set_segment_line_break_after(media_transcript.segments.first, true)
        media_transcript.save!

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
