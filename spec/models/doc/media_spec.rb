# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  subject(:doc) { create(:doc, medium: medium) }

  context 'with medium' do
    let(:medium) { create(:medium) }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: medium) }
    end

    describe 'medium_id immutability' do
      it 'cannot change medium after creation' do
        other_medium = create(:medium, sourcedb: 'DB2', sourceid: 'id2')
        doc.medium = other_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end

  context 'without medium' do
    let(:medium) { nil }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: nil) }
    end

    describe 'medium_id immutability' do
      it 'cannot add medium after creation' do
        new_medium = create(:medium)
        doc.medium = new_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end

  describe 'body immutability with audio or video' do
    { audio: 'audio/mpeg', video: 'video/mp4' }.each do |media_type, content_type|
      it "cannot change the body with an #{media_type} medium" do
        doc = create(:doc, medium: create(:medium, media_type:, content_type:))
        doc.body = 'Changed body'

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Body cannot be changed for a document with audio or video')
      end
    end

    it 'can still change other attributes with an audio medium' do
      doc = create(:doc, medium: create(:medium, media_type: :audio, content_type: 'audio/mpeg'))
      doc.source = 'https://example.com/changed'

      expect(doc).to be_valid
    end

    it 'can change the body with an image medium, even with a media transcript' do
      medium = create(:medium, media_type: :image, content_type: 'image/png')
      doc = create(:doc, medium:)
      MediaTranscript.create!(medium:, doc:, text: doc.body)
      doc.reload.body = 'Changed body'

      expect(doc).to be_valid
    end

    it 'can change the body without a medium' do
      doc = create(:doc)
      doc.body = 'Changed body'

      expect(doc).to be_valid
    end
  end
end
