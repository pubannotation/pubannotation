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

    it 'requires a doc' do
      expect(build(:media_transcript, doc: nil)).not_to be_valid
    end

    it 'requires doc_id to be unique' do
      doc = create(:doc)
      create(:media_transcript, doc: doc)

      expect(build(:media_transcript, doc: doc)).not_to be_valid
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

    it 'belongs to a doc' do
      doc = create(:doc)
      media_transcript = create(:media_transcript, doc: doc)

      expect(media_transcript.doc).to eq(doc)
    end
  end

  describe 'dependent destroy' do
    it 'is destroyed when its doc is destroyed' do
      doc = create(:doc)
      media_transcript = create(:media_transcript, doc: doc)

      doc.destroy

      expect(MediaTranscript.exists?(media_transcript.id)).to be false
    end

    it 'is destroyed when its medium is destroyed' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      media_transcript = create(:media_transcript, medium: medium)

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
      doc = create(:doc)

      media_transcript = MediaTranscript.new(medium: medium, doc: doc)

      expect(media_transcript.segments).to eq([])
    end
  end
end
