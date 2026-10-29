# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'text operations', type: :model do
  describe '#get_text' do
    let(:doc) { build(:doc, body: '0123456789') }

    it 'returns the whole body without a span' do
      expect(doc.get_text).to eq('0123456789')
    end

    it 'uses an exclusive end for the selected span' do
      expect(doc.get_text({ begin: 3, end: 6 })).to eq('345')
    end

    it 'includes the requested context on both sides' do
      expect(doc.get_text({ begin: 3, end: 6 }, 2)).to eq('1234567')
    end

    it 'clips context at both ends of the body' do
      expect(doc.get_text({ begin: 1, end: 9 }, 5)).to eq('0123456789')
    end

    it 'counts Unicode characters rather than bytes' do
      doc.body = '前αβ後'

      expect(doc.get_text({ begin: 1, end: 3 })).to eq('αβ')
    end
  end

  describe '#span and #text' do
    let(:doc) { build(:doc, body: '0123456789') }

    it 'returns nil context entries when context is not requested' do
      params = { begin: '3', end: '6' }

      expect(doc.span(params)).to eq([nil, '345', nil])
      expect(doc.text(params)).to eq('345')
    end

    it 'returns left, focus, and right in that order and joins them for text' do
      params = { begin: '3', end: '6', context_size: '2' }

      expect(doc.span(params)).to eq(['12', '345', '67'])
      expect(doc.text(params)).to eq('1234567')
    end

    it 'clips context at the beginning and end of the body' do
      params = { begin: '1', end: '9', context_size: '5' }

      expect(doc.span(params)).to eq(['0', '12345678', '9'])
      expect(doc.text(params)).to eq('0123456789')
    end
  end

  describe '#get_slices' do
    it 'uses nil to represent the whole body when splitting is unnecessary' do
      doc = build(:doc, body: 'abc')

      expect(doc.get_slices(4)).to eq([nil])
      expect(doc.get_slices(3)).to eq([nil])
    end

    it 'preserves the given span when it fits within the size limit' do
      doc = build(:doc, body: '0123456789')

      expect(doc.get_slices(3, { begin: 2, end: 5 })).to eq([{ begin: 2, end: 5 }])
    end

    it 'splits at the last newline within the limit and excludes separator newlines' do
      doc = build(:doc, body: "a\nbb\nccc\ndd")

      slices = doc.get_slices(6)

      expect(slices).to eq([{ begin: 0, end: 4 }, { begin: 5, end: 11 }])
      expect(slices.map { |slice| doc.get_text(slice) }).to eq(["a\nbb", "ccc\ndd"])
    end

    it 'returns absolute body offsets when splitting a selected span' do
      doc = build(:doc, body: "XXaaa\nbbb\ncccYY")

      slices = doc.get_slices(5, { begin: 2, end: 13 })

      expect(slices).to eq([{ begin: 2, end: 5 }, { begin: 6, end: 9 }, { begin: 10, end: 13 }])
      expect(slices.map { |slice| doc.get_text(slice) }).to eq(%w[aaa bbb ccc])
    end

    it 'raises when an oversized section has no newline within the limit' do
      doc = build(:doc, body: 'abcdef')

      expect { doc.get_slices(3) }.to raise_error(RuntimeError, 'Could not split the document.')
    end
  end

  describe '#set_ascii_body' do
    it 'converts Greek letters and symbols while retaining the original body without saving' do
      original = 'α & β → γ…'
      doc = create(:doc, body: original)

      doc.set_ascii_body

      expect(doc.body).to eq('alpha & beta  to  gamma...')
      expect(doc.original_body).to eq(original)
      expect(doc.body).to be_ascii_only
      expect(Doc.find(doc.id).body).to eq(original)
    end
  end
end
