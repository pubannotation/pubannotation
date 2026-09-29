# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocsHelper, type: :helper do
  describe '#body_with_speech_segments' do
    it "wraps each span's range in a <span> carrying its start_ms" do
      spans = [
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 11, start_ms: 300 }
      ]

      expect(helper.body_with_speech_segments('Hello world', spans)).to eq(
        '<span class="speech-segment" data-start-ms="0">Hello</span> ' \
        '<span class="speech-segment" data-start-ms="300">world</span>'
      )
    end

    it 'HTML-escapes text outside and inside the wrapped spans' do
      spans = [{ begin: 3, end: 5, start_ms: 0 }]

      expect(helper.body_with_speech_segments('<b>Hi</b> & bye', spans)).to eq(
        '&lt;b&gt;<span class="speech-segment" data-start-ms="0">Hi</span>&lt;/b&gt; &amp; bye'
      )
    end

    it 'returns the plain body when there are no spans' do
      expect(helper.body_with_speech_segments('Hello world', [])).to eq('Hello world')
      expect(helper.body_with_speech_segments('Hello world', nil)).to eq('Hello world')
    end
  end

  describe '#body_with_highlighted_span' do
    it 'wraps the span in a .highlight <span> and the text on either side in .context ones' do
      expect(helper.body_with_highlighted_span('Hello big world', { begin: 6, end: 9 })).to eq(
        '<span class="context">Hello </span><span class="highlight">big</span><span class="context"> world</span>'
      )
    end

    it 'HTML-escapes the text inside and outside the highlight' do
      expect(helper.body_with_highlighted_span('<b>Hi</b> & bye', { begin: 3, end: 5 })).to eq(
        '<span class="context">&lt;b&gt;</span><span class="highlight">Hi</span><span class="context">&lt;/b&gt; &amp; bye</span>'
      )
    end
  end
end
