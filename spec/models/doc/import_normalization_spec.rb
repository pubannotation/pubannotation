# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'import normalization', type: :model do
  let(:user) { create(:user) }

  it 'parses filenames using the final hyphen as the source ID separator' do
    expect(Doc.parse_filename('my-source-123')).to eq(['my-source', '123'])
    expect { Doc.parse_filename('invalid') }.to raise_error(ArgumentError, /sourcedb-sourceid/)
  end

  it 'normalizes text and personalizes the source database in place' do
    hdoc = { text: 'Hello', sourcedb: 'Example', sourceid: '123' }

    expect(Doc.hdoc_normalize!(hdoc, user)).to equal(hdoc)
    expect(hdoc).to eq(body: 'Hello', sourcedb: "Example@#{user.username}", sourceid: '123')
  end

  it 'generates the next source ID within the personalized source database' do
    create(:doc, sourcedb: "Example@#{user.username}", sourceid: '9')
    create(:doc, sourcedb: "Example@#{user.username}", sourceid: '10')

    expect(Doc.hdoc_normalize!({ text: 'Hello', sourcedb: 'Example' }, user)[:sourceid]).to eq('11')
  end

  it 'generates a personal source database and initial source ID when omitted' do
    expect(Doc.hdoc_normalize!({ text: 'Hello' }, user)).to eq(
      body: 'Hello', sourcedb: "@#{user.username}", sourceid: '1'
    )
  end

  it 'rejects anonymous uploads and another user source database' do
    expect { Doc.hdoc_normalize!({ text: 'Hello' }, nil) }.to raise_error(SecurityError)
    expect { Doc.hdoc_normalize!({ text: 'Hello', sourcedb: 'Example@someone_else' }, user) }.to raise_error(ArgumentError, /belongs to/)
  end

  it 'preserves explicit source databases when personalization is disabled' do
    expect(Doc.hdoc_normalize!({ body: 'Hello', sourcedb: 'PMC', sourceid: '123' }, user, true)).to eq(
      body: 'Hello', sourcedb: 'PMC', sourceid: '123'
    )
    expect { Doc.hdoc_normalize!({ text: 'Hello' }, user, true) }.to raise_error(ArgumentError, /cannot be automatically generated/)
  end
end
