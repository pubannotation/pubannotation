# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaTranscript, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:media_transcript)).to be_valid
    end

    it 'requires a doc' do
      expect(build(:media_transcript, doc: nil)).not_to be_valid
    end

    it 'requires doc_id to be unique' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      create(:media_transcript, doc: doc)

      expect(build(:media_transcript, doc: doc)).not_to be_valid
    end

    it 'rejects a doc whose medium is an image' do
      medium = create(:medium, media_type: :image, content_type: 'image/jpeg')
      doc = create(:doc, medium: medium)

      expect(build(:media_transcript, doc: doc)).not_to be_valid
    end

    it 'rejects a doc with no medium reference' do
      doc = create(:doc)

      expect(build(:media_transcript, doc: doc)).not_to be_valid
    end
  end

  describe 'associations' do
    it 'derives its medium from the doc' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, doc: doc)

      expect(media_transcript.medium).to eq(medium)
    end

    it 'belongs to a doc' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, doc: doc)

      expect(media_transcript.doc).to eq(doc)
    end
  end

  describe 'dependent destroy' do
    it 'is destroyed when its doc is destroyed' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, doc: doc)

      doc.destroy

      expect(MediaTranscript.exists?(media_transcript.id)).to be false
    end

    it 'is destroyed when its medium is destroyed' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)
      media_transcript = create(:media_transcript, doc: doc)

      medium.destroy

      expect(MediaTranscript.exists?(media_transcript.id)).to be false
    end
  end

  describe 'segments' do
    it 'stores an array of timed text segments' do
      media_transcript = create(:media_transcript, segments: [{ 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100 }])

      expect(media_transcript.reload.segments).to eq([{ 'text' => 'Hi', 'start_ms' => 0, 'end_ms' => 100 }])
    end

    it 'defaults to an empty array' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      doc = create(:doc, medium: medium)

      media_transcript = MediaTranscript.new(doc: doc)

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
  end
end
