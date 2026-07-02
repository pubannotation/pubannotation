# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumUploadEntry do
  describe '#medium_attributes' do
    it 'returns Medium-relevant attributes merged with the given user' do
      entry = described_class.new(
        filename: 'PMC-12345.png', ext: '.png',
        sourcedb: 'PMC', sourceid: '12345',
        media_type: :image, content_type: 'image/png'
      )
      user = build_stubbed(:user)

      expect(entry.medium_attributes(user:)).to eq(
        sourcedb: 'PMC', sourceid: '12345',
        media_type: :image, content_type: 'image/png',
        user:
      )
    end
  end
end
