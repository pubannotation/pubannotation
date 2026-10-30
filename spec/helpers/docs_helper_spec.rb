# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocsHelper, type: :helper do
  describe '#doc_body_tag' do
    let(:doc) { build(:doc, body: 'Hello world') }
    let(:spans) do
      [
        { begin: 0, end: 5, start_ms: 0 },
        { begin: 6, end: 11, start_ms: 300 }
      ]
    end

    it 'renders the plain, HTML-escaped body without speech segments or a selected span' do
      expect(helper.doc_body_tag(build(:doc, body: '<b>Hi</b>'))).to eq('<div id="body">&lt;b&gt;Hi&lt;/b&gt;</div>')
    end

    it 'wraps the body in speech segments' do
      expect(helper.doc_body_tag(doc, speech_segment_spans: spans)).to eq(
        '<div id="body"><span class="speech-segment" data-start-ms="0">Hello</span> ' \
        '<span class="speech-segment" data-start-ms="300">world</span></div>'
      )
    end

    it 'highlights the selected span inside the speech segments, marking the <div> with_hilight' do
      expect(helper.doc_body_tag(doc, speech_segment_spans: spans, selected_span: { begin: 0, end: 5 })).to eq(
        '<div id="body" class="with_hilight"><span class="speech-segment" data-start-ms="0">' \
        '<span class="highlight">Hello</span></span> <span class="speech-segment" data-start-ms="300">world</span></div>'
      )
    end

    it 'highlights the selected span without speech segments, marking the <div> with_hilight' do
      expect(helper.doc_body_tag(doc, selected_span: { begin: 0, end: 5 })).to eq(
        '<div id="body" class="with_hilight">' + helper.body_with_highlighted_span(doc.body, { begin: 0, end: 5 }) + '</div>'
      )
    end
  end

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

    context 'with a selected span' do
      let(:spans) do
        [
          { begin: 0, end: 5, start_ms: 0 },
          { begin: 6, end: 11, start_ms: 300 }
        ]
      end

      it 'wraps the selected text inside a segment in a .highlight <span>' do
        expect(helper.body_with_speech_segments('Hello world', spans, selected_span: { begin: 1, end: 4 })).to eq(
          '<span class="speech-segment" data-start-ms="0">H<span class="highlight">ell</span>o</span> ' \
          '<span class="speech-segment" data-start-ms="300">world</span>'
        )
      end

      it 'splits a selected span that crosses segments at their boundaries, including the text between them' do
        expect(helper.body_with_speech_segments('Hello world', spans, selected_span: { begin: 3, end: 8 })).to eq(
          '<span class="speech-segment" data-start-ms="0">Hel<span class="highlight">lo</span></span>' \
          '<span class="highlight"> </span>' \
          '<span class="speech-segment" data-start-ms="300"><span class="highlight">wo</span>rld</span>'
        )
      end

      it 'HTML-escapes the selected text' do
        expect(helper.body_with_speech_segments('<b> & c', [{ begin: 4, end: 7, start_ms: 0 }], selected_span: { begin: 0, end: 5 })).to eq(
          '<span class="highlight">&lt;b&gt; </span>' \
          '<span class="speech-segment" data-start-ms="0"><span class="highlight">&amp;</span> c</span>'
        )
      end
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
