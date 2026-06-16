# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'medium association' do
    let(:medium) { create(:medium, sourcedb: 'MediaDB', sourceid: 'img-001') }

    it 'returns the associated Medium via belongs_to' do
      doc = create(:doc, media_sourcedb: medium.sourcedb, media_sourceid: medium.sourceid)
      expect(doc.medium).to eq(medium)
    end

    it 'medium is nil when media_sourcedb/media_sourceid are not set' do
      doc = create(:doc)
      expect(doc.medium).to be_nil
    end
  end

  describe 'media resolution' do
    it 'is valid when media is not specified' do
      expect(build(:doc)).to be_valid
    end

    it 'resolves medium_id from media_sourcedb/media_sourceid before save' do
      medium = create(:medium)
      doc = create(:doc, media_sourcedb: medium.sourcedb, media_sourceid: medium.sourceid)
      expect(doc.medium_id).to eq(medium.id)
    end

    it 'is invalid when the specified media does not exist' do
      doc = build(:doc, media_sourcedb: 'NonExistDB', media_sourceid: 'no-such-id')
      expect(doc).not_to be_valid
      expect(doc.errors[:base]).to include('Specified media does not exist')
    end
  end

  describe 'medium_id immutability' do
    it 'cannot change medium after creation' do
      medium1 = create(:medium, sourcedb: 'DB1', sourceid: 'id1')
      medium2 = create(:medium, sourcedb: 'DB2', sourceid: 'id2')
      doc = create(:doc, media_sourcedb: medium1.sourcedb, media_sourceid: medium1.sourceid)
      doc.medium = medium2
      expect(doc).not_to be_valid
      expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
    end
  end
end
