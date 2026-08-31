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
      doc = create(:doc)
      create(:media_transcript, doc: doc)

      expect(build(:media_transcript, doc: doc)).not_to be_valid
    end

    it 'allows multiple records with no doc' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      create(:media_transcript, medium: medium, doc: nil)

      expect(build(:media_transcript, medium: medium, doc: nil)).to be_valid
    end

    it 'rejects a medium whose media_type is image' do
      medium = create(:medium, media_type: :image, content_type: 'image/jpeg')

      expect(build(:media_transcript, medium: medium)).not_to be_valid
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
      doc = create(:doc)
      media_transcript = create(:media_transcript, doc: doc)

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

    it 'is not destroyed when its doc is destroyed, but the reference is nullified' do
      doc = create(:doc)
      media_transcript = create(:media_transcript, doc: doc)

      doc.destroy

      expect(media_transcript.reload.doc_id).to be_nil
    end
  end

  describe '#speech_segments and #speech?' do
    it 'includes all segments and is speech when every segment is spoken text' do
      media_transcript = build(:media_transcript, segments: [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
      ])

      expect(media_transcript.speech_segments).to eq(media_transcript.segments)
      expect(media_transcript).to be_speech
    end

    it 'excludes non-speech segments and is not speech when none remain' do
      media_transcript = build(:media_transcript, segments: [
        { 'text' => '(upbeat music)', 'start_ms' => 0, 'end_ms' => 3000 }
      ])

      expect(media_transcript.speech_segments).to eq([])
      expect(media_transcript).not_to be_speech
    end

    it 'is speech when at least one segment is spoken text alongside non-speech segments' do
      media_transcript = build(:media_transcript, segments: [
        { 'text' => '(upbeat music)', 'start_ms' => 0, 'end_ms' => 3000 },
        { 'text' => 'Welcome to the conference.', 'start_ms' => 3000, 'end_ms' => 6000 }
      ])

      expect(media_transcript.speech_segments).to eq([
        { 'text' => 'Welcome to the conference.', 'start_ms' => 3000, 'end_ms' => 6000 }
      ])
      expect(media_transcript).to be_speech
    end

    it 'is not speech for an empty segments array' do
      media_transcript = build(:media_transcript, segments: [])

      expect(media_transcript).not_to be_speech
    end
  end

  describe '#body' do
    it 'joins the text of only the speech segments' do
      media_transcript = build(:media_transcript, segments: [
        { 'text' => '(upbeat music)', 'start_ms' => 0, 'end_ms' => 3000 },
        { 'text' => 'Welcome to the conference.', 'start_ms' => 3000, 'end_ms' => 6000 }
      ])

      expect(media_transcript.body).to eq('Welcome to the conference.')
    end

    it 'is blank when there are no speech segments' do
      media_transcript = build(:media_transcript, segments: [{ 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 100 }])

      expect(media_transcript.body).to eq('')
    end
  end

  describe 'segments' do
    it 'stores an array of timed text segments' do
      media_transcript = create(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100 }])

      expect(media_transcript.reload.segments).to eq([{ 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100 }])
    end

    it 'defaults to an empty array' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

      media_transcript = MediaTranscript.new(medium: medium)

      expect(media_transcript.segments).to eq([])
    end

    it 'is valid with an empty array' do
      expect(build(:media_transcript, segments: [])).to be_valid
    end

    it 'is valid when a segment has equal start_ms and end_ms' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 100, 'end_ms' => 100 }])).to be_valid
    end

    it 'rejects segments that are not an array' do
      expect(build(:media_transcript, segments: { 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100 })).not_to be_valid
    end

    it 'rejects a segment missing required keys' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 0 }])).not_to be_valid
    end

    it 'rejects a segment whose text is not a string' do
      expect(build(:media_transcript, segments: [{ 'text' => nil, 'start_ms' => 0, 'end_ms' => 100 }])).not_to be_valid
    end

    it 'rejects a segment with a negative start_ms' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => -1, 'end_ms' => 100 }])).not_to be_valid
    end

    it 'rejects a segment whose start_ms is not an integer' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => '0', 'end_ms' => 100 }])).not_to be_valid
    end

    it 'rejects a segment whose end_ms is not an integer' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100.0 }])).not_to be_valid
    end

    it 'rejects a segment that is not a hash' do
      expect(build(:media_transcript, segments: ['not a hash'])).not_to be_valid
    end

    it 'rejects a segment whose end_ms is before its start_ms' do
      expect(build(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 100, 'end_ms' => 0 }])).not_to be_valid
    end

    it 'rejects segments that are out of chronological order' do
      segments = [
        { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 },
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 }
      ]

      expect(build(:media_transcript, segments: segments)).not_to be_valid
    end

    it 'rejects overlapping segments' do
      segments = [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 100, 'end_ms' => 400 }
      ]

      expect(build(:media_transcript, segments: segments)).not_to be_valid
    end

    it 'allows a gap between segments' do
      segments = [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 800 }
      ]

      expect(build(:media_transcript, segments: segments)).to be_valid
    end
  end
end
