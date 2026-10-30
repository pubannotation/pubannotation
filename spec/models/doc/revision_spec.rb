# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'revision', type: :model do
  describe '#revise' do
    it 'leaves a body that only differs in its line endings as it is, not aligning the annotations' do
      doc = create(:doc, body: "Hello\nworld")
      expect(AnnotationUtils).not_to receive(:align_denotations_and_blocks!)

      doc.revise({ text: "Hello\r\nworld" })

      expect(doc.reload.body).to eq("Hello\nworld")
    end

    it 'moves the annotations to where their text is in the new body as stored, with LF line endings' do
      doc = create(:doc, body: 'Hello world')
      denotation = create(:denotation, doc:, begin: 6, end: 11)

      doc.revise({ text: "Hello\r\nbig world" })

      doc.reload
      denotation.reload
      expect(doc.body).to eq("Hello\nbig world")
      expect([denotation.begin, denotation.end]).to eq([10, 15])
      expect(doc.body[denotation.begin...denotation.end]).to eq('world')
    end
  end

  describe '#revise text structures' do
    let(:doc) { create(:doc, body: 'Hello world') }

    ['Hello world', 'Hello big world'].each do |text|
      it "replaces divisions and typesettings when revising to #{text.inspect}" do
        doc.divisions.create!(begin: 0, end: 5, label: 'old')
        doc.typesettings.create!(begin: 0, end: 5, style: 'old')
        divisions = [{ span: { begin: 0, end: text.length }, label: 'p' }]
        typesettings = [{ span: { begin: 0, end: 5 }, style: 'bold' }]

        expect(doc.revise({ body: text, divisions: divisions, typesettings: typesettings })).to eq([])

        expect(doc.reload.body).to eq(text)
        expect(doc.divisions.map(&:to_hash)).to eq(divisions)
        expect(doc.typesettings.map(&:to_hash)).to eq(typesettings)
      end
    end

    it 'persists the aligned block positions along with denotations' do
      denotation = create(:denotation, doc: doc, begin: 6, end: 11)
      block = create(:block, doc: doc, begin: 6, end: 11)

      doc.revise({ text: 'Hello big world' })

      expect([block.reload.begin, block.end]).to eq([10, 15])
      expect([denotation.reload.begin, denotation.end]).to eq([10, 15])
    end
  end

  describe '.uptodate' do
    let(:doc) { create(:doc, sourcedb: 'PMC', sourceid: '123', body: 'Hello world') }
    let(:hdoc) { { text: 'Hello big world' } }

    it 'revises from a supplied document without fetching it' do
      expect(DocumentFetcher).not_to receive(:fetch)

      expect(Doc.uptodate(doc, hdoc)).to eq([])
      expect(doc.reload.body).to eq('Hello big world')
    end

    it 'fetches the document from its source when no replacement is supplied' do
      expect(DocumentFetcher).to receive(:fetch).with('PMC', ['123']).and_return([[hdoc], []])

      expect(Doc.uptodate(doc)).to eq([])
      expect(doc.reload.body).to eq('Hello big world')
    end

    it 'reports the source error without revising when no document is returned' do
      allow(DocumentFetcher).to receive(:fetch).with('PMC', ['123']).and_return([[], [{ body: 'Not found' }]])

      expect { Doc.uptodate(doc) }.to raise_error(RuntimeError, 'Could not sequence the document, PMC:123: Not found')
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'rejects multiple fetched documents even when there are no source messages' do
      allow(DocumentFetcher).to receive(:fetch).with('PMC', ['123']).and_return([[hdoc, hdoc], []])

      expect { Doc.uptodate(doc) }.to raise_error(RuntimeError, 'Could not sequence the document, PMC:123')
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'rolls back structure replacement if saving the revised structures fails' do
      division = doc.divisions.create!(begin: 0, end: 5, label: 'p')
      typesetting = doc.typesettings.create!(begin: 0, end: 5, style: 'bold')
      allow(doc).to receive(:store_typesettings).and_raise('Storage failed')

      expect { Doc.uptodate(doc, { text: 'Hello world', divisions: [] }) }.to raise_error('Storage failed')

      doc.reload
      expect(doc.divisions).to eq([division])
      expect(doc.typesettings).to eq([typesetting])
    end
  end
end
