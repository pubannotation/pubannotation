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

    it 'requires media_type' do
      expect(build(:medium, media_type: nil)).not_to be_valid
    end

    it 'requires content_type' do
      expect(build(:medium, content_type: nil)).not_to be_valid
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
end
