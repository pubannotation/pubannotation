# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Segment, type: :model do
  describe 'validations' do
    it 'is valid with a sort order, text and times' do
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

    it 'requires line_break_after, which a blank value casts to nil' do
      segment = build(:segment, line_break_after: '')

      expect(segment).not_to be_valid
      expect(segment.errors[:line_break_after]).to include("can't be nil")
    end

    it 'requires a non-negative integer sort order' do
      expect(build(:segment, sort_order: -1)).not_to be_valid
      expect(build(:segment, sort_order: 1.5)).not_to be_valid
    end

    it 'requires non-negative integer times' do
      expect(build(:segment, start_ms: -1)).not_to be_valid
      expect(build(:segment, end_ms: 1.5)).not_to be_valid
    end

    it 'requires a sort order and times, reporting a missing one only as blank' do
      { sort_order: nil, start_ms: nil, end_ms: nil }.each do |attribute, value|
        segment = build(:segment, attribute => value)

        expect(segment).not_to be_valid
        expect(segment.errors.to_hash).to eq(attribute => ["can't be blank"])
      end
    end

    it 'requires the end to be no earlier than the start' do
      expect(build(:segment, start_ms: 300, end_ms: 300)).to be_valid
      expect(build(:segment, start_ms: 300, end_ms: 299)).not_to be_valid
    end

    context 'with the segment before it in its transcript' do
      let(:media_transcript) { create(:media_transcript) }

      it 'requires the start to be no earlier than its end' do
        segment = media_transcript.segments.build(sort_order: 2, text: 'again', start_ms: 599, end_ms: 900)

        expect(segment).not_to be_valid
        expect(segment.errors[:start_ms]).to include("must be greater than or equal to the previous segment's end_ms (600)")
      end

      it 'allows it to start right at its end' do
        expect(media_transcript.segments.build(sort_order: 2, text: 'again', start_ms: 600, end_ms: 900)).to be_valid
      end

      it 'looks only at segments before it in sort order' do
        expect(media_transcript.segments.build(sort_order: 0, text: 'Hi', start_ms: 0, end_ms: 100)).to be_valid
      end

      it 'compares one loaded on its own as changed, not as stored' do
        segment = Segment.find(media_transcript.segments.last.id)
        segment.sort_order = 2

        expect(segment).to be_valid
      end

      it 'leaves out one marked for destruction' do
        media_transcript.segments.last.mark_for_destruction

        expect(media_transcript.segments.build(sort_order: 2, text: 'again', start_ms: 300, end_ms: 900)).to be_valid
      end
    end
  end

  describe 'text' do
    it 'is stored with tabs as spaces' do
      expect(create(:segment, text: "Hello\tworld").reload.text).to eq('Hello world')
    end

    it 'is stored with runs of spaces, including ones from tabs, as one space' do
      expect(create(:segment, text: "Hello  \t world   again").reload.text).to eq('Hello world again')
    end

    it 'is stored with nothing around it, including line breaks' do
      expect(create(:segment, text: " \tHello world \r\n").reload.text).to eq('Hello world')
    end

    it 'is stored with line breaks within it as spaces' do
      %W[Hello\nworld Hello\r\nworld Hello\rworld Hello\n\nworld Hello\s\nworld].each do |text|
        expect(create(:segment, text:).reload.text).to eq('Hello world')
      end
    end

    it 'is stored blank when it is only spaces' do
      expect(create(:segment, text: '   ').reload.text).to eq('')
    end
  end

  describe 'line_break_after' do
    it 'defaults to false' do
      expect(create(:segment).line_break_after).to be(false)
    end
  end

  describe '#separator_after' do
    it 'is a space' do
      expect(build(:segment).separator_after).to eq(' ')
    end

    it 'is a line break with one after it' do
      expect(build(:segment, line_break_after: true).separator_after).to eq("\n")
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
