# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentFetcher, type: :model do
  let(:sourcedb) { 'PMC' }
  let(:hdoc) { { sourcedb: sourcedb, sourceid: '001', text: 'Hello world' } }
  let(:sequencer) { instance_double(Sequencer) }

  describe '.fetch' do
    before do
      allow(Sequencer).to receive(:find).with(sourcedb).and_return(sequencer)
    end

    it 'excludes entries missing required fields and preserves sequencer messages' do
      invalid = [hdoc.merge(sourceid: '002', text: ''), hdoc.merge(sourceid: '003', sourcedb: ''), hdoc.merge(sourceid: nil)]
      upstream_message = { sourcedb: sourcedb, sourceid: ['004'], body: 'Gateway error' }
      allow(sequencer).to receive(:get_docs).with(%w[001 002 003 004]).and_return([[hdoc, *invalid], [upstream_message]])

      docs, messages = described_class.fetch(sourcedb, %w[001 002 003 004])

      expect(docs).to eq([hdoc])
      expect(messages).to eq([
        upstream_message,
        { sourcedb: sourcedb, sourceid: ['002'], body: 'Invalid document entry.' },
        { sourcedb: sourcedb, sourceid: ['003'], body: 'Invalid document entry.' },
        { sourcedb: sourcedb, sourceid: [nil], body: 'Invalid document entry.' }
      ])
    end

    it 'rejects an empty source database or source ID list' do
      expect { described_class.fetch('', ['001']) }.to raise_error(ArgumentError, 'sourcedb is empty')
      expect { described_class.fetch(sourcedb, []) }.to raise_error(ArgumentError, 'sourceids is empty')
    end

    it 'rejects blank inputs before looking up a sequencer' do
      expect(Sequencer).not_to receive(:find)

      expect { described_class.fetch(nil, ['001']) }.to raise_error(ArgumentError, 'sourcedb is empty')
      expect { described_class.fetch(' ', ['001']) }.to raise_error(ArgumentError, 'sourcedb is empty')
      expect { described_class.fetch(sourcedb, nil) }.to raise_error(ArgumentError, 'sourceids is empty')
    end

    it 'returns source messages when no documents are obtained' do
      messages = [{ sourcedb: sourcedb, sourceid: ['001'], body: 'Not found' }]
      allow(sequencer).to receive(:get_docs).with(['001']).and_return([[], messages])

      expect(described_class.fetch(sourcedb, ['001'])).to eq([[], messages])
    end

    it 'propagates retrieval errors without treating them as a missing sequencer' do
      allow(sequencer).to receive(:get_docs).with(['001']).and_raise(ActiveRecord::ConnectionNotEstablished, 'Connection lost')

      expect { described_class.fetch(sourcedb, ['001']) }.to raise_error(ActiveRecord::ConnectionNotEstablished, 'Connection lost')
    end

    it 'reports a missing sequencer' do
      allow(Sequencer).to receive(:find).with(sourcedb).and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.fetch(sourcedb, ['001']) }.to raise_error(ArgumentError, "Could not find the sequencer for the sourcedb: [#{sourcedb}]")
    end

    it 'explains that personal documents must be uploaded' do
      allow(Sequencer).to receive(:find).with('Example@alice').and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.fetch('Example@alice', ['001']) }.to raise_error(ArgumentError, 'User documents cannot be automatically obtained. Please upload them yourself.')
    end
  end
end
