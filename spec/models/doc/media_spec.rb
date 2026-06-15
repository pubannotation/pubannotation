# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe '#media' do
    let(:medium) { create(:medium, sourcedb: 'MediaDB', sourceid: 'img-001') }

    it 'returns the associated Medium' do
      doc = create(:doc, media_sourcedb: medium.sourcedb, media_sourceid: medium.sourceid)
      expect(doc.media).to eq(medium)
    end

    it 'returns nil when media_sourcedb is not set' do
      doc = create(:doc, media_sourcedb: nil, media_sourceid: nil)
      expect(doc.media).to be_nil
    end
  end

  describe 'media validation' do
    it 'is valid when media is not specified' do
      expect(build(:doc, media_sourcedb: nil, media_sourceid: nil)).to be_valid
    end

    it 'is valid when the specified media exists' do
      medium = create(:medium)
      expect(build(:doc, media_sourcedb: medium.sourcedb, media_sourceid: medium.sourceid)).to be_valid
    end

    it 'is invalid when the specified media does not exist' do
      doc = build(:doc, media_sourcedb: 'NonExistDB', media_sourceid: 'no-such-id')
      expect(doc).not_to be_valid
      expect(doc.errors[:base]).to include('Specified media does not exist')
    end
  end
end
