# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'document import', type: :model do
  # Exercise the import's own transaction, including rollback after related rows
  # have been written, without a surrounding fixture transaction.
  self.use_transactional_tests = false

  let(:sourcedb) { "ImportSpec#{SecureRandom.hex(8)}" }
  let(:hdoc) { { sourcedb: sourcedb, sourceid: '001', text: 'Hello world' } }
  let(:sequencer) { instance_double(Sequencer) }

  after do
    Doc.where(sourcedb: sourcedb).destroy_all
  end

  describe '.store_hdoc!' do
    it 'persists the text, source, divisions, and typesettings' do
      divisions = [{ span: { begin: 0, end: 11 }, label: 'p' }]
      typesettings = [{ span: { begin: 0, end: 5 }, style: 'bold' }]

      doc = Doc.store_hdoc!(hdoc.merge(source: 'https://example.com/original', divisions: divisions, typesettings: typesettings))

      expect(doc.reload).to have_attributes(body: 'Hello world', sourcedb: sourcedb, sourceid: '001', source: 'https://example.com/original')
      expect(doc.divisions.map(&:to_hash)).to eq(divisions)
      expect(doc.typesettings.map(&:to_hash)).to eq(typesettings)
    end

    it 'accepts body when text is absent' do
      doc = Doc.store_hdoc!(hdoc.except(:text).merge(body: 'Body input'))

      expect(doc.reload.body).to eq('Body input')
    end

    it 'prefers text when both text and body are supplied' do
      doc = Doc.store_hdoc!(hdoc.merge(body: 'Other input'))

      expect(doc.reload.body).to eq('Hello world')
    end

    it 'rolls back the document and its related rows when saving fails' do
      input = hdoc.merge(
        divisions: [{ span: { begin: 0, end: 11 }, label: 'p' }],
        typesettings: [{ span: { begin: 0, end: 5 }, style: 'bold' }]
      )
      allow(Typesetting).to receive(:import).and_wrap_original do |original, *args|
        original.call(*args)
        raise 'Typesetting storage failed'
      end

      expect do
        expect { Doc.store_hdoc!(input) }.to raise_error(RuntimeError, 'Typesetting storage failed')
      end.not_to change { [Doc.count, Division.count, Typesetting.count] }
      expect(Doc.where(sourcedb: sourcedb)).to be_empty
    end

    it 'raises on a duplicate without changing the existing document' do
      existing = Doc.store_hdoc!(hdoc)

      expect { Doc.store_hdoc!(hdoc.merge(text: 'Replacement')) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(existing.reload.body).to eq('Hello world')
      expect(Doc.where(sourcedb: sourcedb).count).to eq(1)
    end
  end

  describe '.store_hdoc' do
    it 'returns the existing document on a duplicate without replacing its text' do
      existing = Doc.store_hdoc!(hdoc)

      expect(Doc.store_hdoc(hdoc.merge(text: 'Replacement'))).to eq(existing)
      expect(existing.reload.body).to eq('Hello world')
      expect(Doc.where(sourcedb: sourcedb).count).to eq(1)
    end

    it 'returns the existing document when the database reports a uniqueness conflict' do
      existing = Doc.store_hdoc!(hdoc)
      allow(Doc).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique, 'duplicate key value violates unique constraint')

      expect(Doc.store_hdoc(hdoc)).to eq(existing)
    end

    it 'propagates validation failures unrelated to duplicates' do
      expect { Doc.store_hdoc(hdoc.merge(text: '')) }.to raise_error(ActiveRecord::RecordInvalid, /text/)

      expect(Doc.where(sourcedb: sourcedb)).to be_empty
    end
  end

  describe '.store_hdocs' do
    it 'saves documents before and after an invalid entry and reports its failure' do
      inputs = [hdoc, hdoc.merge(sourceid: '002', text: ''), hdoc.merge(sourceid: '003')]

      docs, messages = Doc.store_hdocs(inputs)

      expect(docs.map(&:sourceid)).to eq(%w[001 003])
      expect(Doc.where(sourcedb: sourcedb).pluck(:sourceid)).to match_array(%w[001 003])
      expect(messages).to match([{ sourcedb: sourcedb, sourceid: ['002'], body: a_string_matching(/text can't be blank/) }])
    end

    it 'returns empty results for an empty input' do
      expect(Doc.store_hdocs([])).to eq([[], []])
    end
  end

  describe '.sequence_and_store_doc!' do
    before do
      allow(Sequencer).to receive(:find).with(sourcedb).and_return(sequencer)
    end

    it 'fetches and persists a single document' do
      allow(sequencer).to receive(:get_docs).with(['001']).and_return([[hdoc], []])

      doc = Doc.sequence_and_store_doc!(sourcedb, '001')

      expect(doc.reload).to have_attributes(sourcedb: sourcedb, sourceid: '001', body: 'Hello world')
    end

    it 'raises the retrieval message when no document was obtained' do
      allow(sequencer).to receive(:get_docs).with(['001']).and_return([[], [{ body: 'Gateway error' }]])

      expect { Doc.sequence_and_store_doc!(sourcedb, '001') }.to raise_error(RuntimeError, 'Gateway error')
      expect(Doc.where(sourcedb: sourcedb)).to be_empty
    end
  end

  describe '.sequence_and_store_docs' do
    it 'combines retrieval and storage errors while persisting the other documents' do
      upstream_message = { sourcedb: sourcedb, sourceid: ['004'], body: 'Gateway error' }
      inputs = [hdoc, hdoc.merge(sourceid: '002', typesettings: []), hdoc.merge(sourceid: '003')]
      allow(Sequencer).to receive(:find).with(sourcedb).and_return(sequencer)
      allow(sequencer).to receive(:get_docs).with(%w[001 002 003 004]).and_return([inputs, [upstream_message]])
      allow(Typesetting).to receive(:import).and_raise('Typesetting storage failed')

      docs, messages = Doc.sequence_and_store_docs(sourcedb, %w[001 002 003 004])

      expect(docs.map(&:sourceid)).to eq(%w[001 003])
      expect(Doc.where(sourcedb: sourcedb).pluck(:sourceid)).to match_array(%w[001 003])
      expect(messages).to eq([
        upstream_message,
        { sourcedb: sourcedb, sourceid: ['002'], body: 'Typesetting storage failed' }
      ])
    end
  end
end
