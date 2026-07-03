# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumUploadEntry do
  describe '#create_medium' do
    it 'creates a Medium with an attached file' do
      entry = described_class.new(
        filename: 'PMC-12345.png', ext: '.png',
        sourcedb: 'PMC', sourceid: '12345',
        media_type: :image, content_type: 'image/png'
      )
      user = create(:user)
      io = File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png'), 'rb')

      medium = entry.create_medium(user:, io:)

      expect(medium).to be_persisted
      expect(medium).to have_attributes(
        sourcedb: 'PMC',
        sourceid: '12345',
        media_type: 'image',
        content_type: 'image/png',
        user:
      )
      expect(medium.file).to be_attached
      expect(medium.file.filename.to_s).to eq('PMC-12345.png')
    ensure
      io&.close
    end
  end
end
