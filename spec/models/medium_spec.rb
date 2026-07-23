# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Medium, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:medium)).to be_valid
    end

    it 'requires sourcedb' do
      expect(build(:medium, sourcedb: nil)).not_to be_valid
    end

    it 'requires sourceid' do
      expect(build(:medium, sourceid: nil)).not_to be_valid
    end

    it 'requires sourcedb and sourceid to be unique in combination' do
      create(:medium, sourcedb: 'DB1', sourceid: 'id1')
      expect(build(:medium, sourcedb: 'DB1', sourceid: 'id1')).not_to be_valid
    end

    it 'allows the same sourceid with a different sourcedb' do
      create(:medium, sourcedb: 'DB1', sourceid: 'id1')
      expect(build(:medium, sourcedb: 'DB2', sourceid: 'id1')).to be_valid
    end

    it 'requires media_type when it cannot be derived from content_type' do
      expect(build(:medium, media_type: nil, content_type: nil)).not_to be_valid
    end

    it 'requires content_type' do
      expect(build(:medium, content_type: nil)).not_to be_valid
    end

    it 'derives media_type from content_type when media_type is not set' do
      medium = build(:medium, media_type: nil, content_type: 'video/mp4')
      expect(medium).to be_valid
      expect(medium.media_type).to eq('video')
    end

    it 'does not override an explicitly set media_type' do
      medium = build(:medium, media_type: :video, content_type: 'image/png')
      medium.valid?
      expect(medium.media_type).to eq('video')
    end

    it 'accepts a browser-playable video content_type' do
      expect(build(:medium, media_type: :video, content_type: 'video/mp4')).to be_valid
    end

    it 'rejects a content_type browsers cannot play inline, such as video/quicktime' do
      medium = build(:medium, media_type: :video, content_type: 'video/quicktime')
      expect(medium).not_to be_valid
      expect(medium.errors[:content_type]).to be_present
    end
  end

  describe 'enums' do
    it 'defines media_type values' do
      expect(Medium.media_types.keys).to contain_exactly('image', 'video', 'audio')
    end
  end

  describe 'ActiveStorage' do
    it 'has one attached file' do
      expect(Medium.new).to respond_to(:file)
    end
  end

  describe 'dependent destroy' do
    it 'destroys associated docs when medium is deleted' do
      medium = create(:medium)
      create(:doc, medium: medium)
      expect { medium.destroy }.to change(Doc, :count).by(-1)
    end
  end
end
