# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentImportNormalizer do
  let(:user) { create(:user) }

  it 'parses filenames using the final hyphen as the source ID separator' do
    expect(DocumentImportNormalizer.parse_filename('my-source-123')).to eq(['my-source', '123'])
    expect { DocumentImportNormalizer.parse_filename('invalid') }.to raise_error(ArgumentError, /sourcedb-sourceid/)
  end

  it 'normalizes text and personalizes the source database in place' do
    hdoc = { text: 'Hello', sourcedb: 'Example', sourceid: '123' }

    expect(described_class.normalize!(hdoc, user)).to equal(hdoc)
    expect(hdoc).to eq(body: 'Hello', sourcedb: "Example@#{user.username}", sourceid: '123')
  end

  it 'generates the next source ID within the personalized source database' do
    create(:doc, sourcedb: "Example@#{user.username}", sourceid: '9')
    create(:doc, sourcedb: "Example@#{user.username}", sourceid: '10')

    expect(described_class.normalize!({ text: 'Hello', sourcedb: 'Example' }, user)[:sourceid]).to eq('11')
  end

  it 'generates a personal source database and initial source ID when omitted' do
    expect(described_class.normalize!({ text: 'Hello' }, user)).to eq(
      body: 'Hello', sourcedb: "@#{user.username}", sourceid: '1'
    )
  end

  it 'rejects anonymous uploads and another user source database' do
    expect { described_class.normalize!({ text: 'Hello' }, nil) }.to raise_error(SecurityError)
    expect { described_class.normalize!({ text: 'Hello', sourcedb: 'Example@someone_else' }, user) }.to raise_error(ArgumentError, /belongs to/)
  end

  it 'preserves explicit source databases when personalization is disabled' do
    expect(described_class.normalize!({ body: 'Hello', sourcedb: 'PMC', sourceid: '123' }, user, true)).to eq(
      body: 'Hello', sourcedb: 'PMC', sourceid: '123'
    )
    expect { described_class.normalize!({ text: 'Hello' }, user, true) }.to raise_error(ArgumentError, /cannot be automatically generated/)
  end

  it 'retains a source database already personalized for the current user' do
    sourcedb = "Example@#{user.username}"

    expect(described_class.normalize!({ text: 'Hello', sourcedb: sourcedb, sourceid: '123' }, user)).to eq(
      body: 'Hello', sourcedb: sourcedb, sourceid: '123'
    )
  end

  it 'rejects multiple username separators in a source database' do
    expect do
      described_class.normalize!({ text: 'Hello', sourcedb: "Example@#{user.username}@extra" }, user)
    end.to raise_error(ArgumentError, /special character reserved/)
  end

  it 'prefers an existing body over text and removes the text field' do
    hdoc = { body: 'Original', text: 'Other', sourceid: '123' }

    expect(described_class.normalize!(hdoc, user)).to include(body: 'Original')
    expect(hdoc).not_to have_key(:text)
  end

  it 'rejects input with neither body nor text' do
    expect { described_class.normalize!({}, user) }.to raise_error(ArgumentError, 'Text is missing.')
  end

  describe '.validate_sourcedb!' do
    it 'requires an explicit source database when personalization is disabled' do
      expect { described_class.validate_sourcedb!(nil, true) }.to raise_error(ArgumentError, /cannot be automatically generated/)
      expect { described_class.validate_sourcedb!('PMC', true) }.not_to raise_error
    end

    it 'allows a missing source database when personalization is enabled' do
      expect { described_class.validate_sourcedb!(nil, false) }.not_to raise_error
    end
  end

end
