# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Segment, type: :model do
  describe 'validations' do
    it 'is valid with a position, text and times' do
      expect(build(:segment)).to be_valid
    end

    it 'is valid with blank text, which Whisper can transcribe a segment as' do
      expect(build(:segment, text: '')).to be_valid
    end

    it 'requires text' do
      segment = build(:segment, text: nil)

      expect(segment).not_to be_valid
      expect(segment.errors[:text]).to include("can't be nil")
    end

    it 'requires a non-negative integer position' do
      expect(build(:segment, position: -1)).not_to be_valid
      expect(build(:segment, position: 1.5)).not_to be_valid
      expect(build(:segment, position: nil)).not_to be_valid
    end

    it 'requires non-negative integer times' do
      expect(build(:segment, start_ms: -1)).not_to be_valid
      expect(build(:segment, end_ms: 1.5)).not_to be_valid
      expect(build(:segment, start_ms: nil)).not_to be_valid
    end

    it 'requires the end to be no earlier than the start' do
      expect(build(:segment, start_ms: 300, end_ms: 300)).to be_valid
      expect(build(:segment, start_ms: 300, end_ms: 299)).not_to be_valid
    end

    it 'requires a media transcript' do
      expect(build(:segment, media_transcript: nil)).not_to be_valid
    end
  end

  describe 'line_break_after' do
    it 'defaults to false' do
      expect(create(:segment).line_break_after).to be(false)
    end
  end

  describe '#speech?' do
    it 'is true for speech' do
      expect(build(:segment, text: 'Hello world')).to be_speech
    end

    it 'is false for a non-speech label' do
      expect(build(:segment, text: '(music)')).not_to be_speech
    end

    it 'is false for blank text' do
      expect(build(:segment, text: '')).not_to be_speech
    end
  end

  it 'goes along with its media transcript as it is deleted' do
    segment = create(:segment)

    MediaTranscript.where(id: segment.media_transcript_id).delete_all

    expect(Segment.exists?(segment.id)).to be(false)
  end
end
