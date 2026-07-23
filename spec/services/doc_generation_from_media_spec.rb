# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocGenerationFromMedia do
  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:project) { create(:project, user: user) }
  let(:image_medium) do
    medium = create(:medium)
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
      filename: 'test_image.png',
      content_type: 'image/png'
    )
    medium
  end

  describe '#call' do
    context 'with a valid image medium' do
      before do
        allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))
      end

      it 'creates a doc with the generated caption, linked to the medium and the project' do
        doc = described_class.new(
          project: project,
          medium: image_medium,
          user: user,
          attributes: { source: nil, sourcedb: 'Example', sourceid: '001' }
        ).call

        expect(doc).to be_persisted
        expect(doc.body).to eq('A generated caption.')
        expect(doc.sourcedb).to eq("Example@#{user.username}")
        expect(doc.sourceid).to eq('001')
        expect(doc.medium).to eq(image_medium)
        expect(project.docs).to include(doc)
      end
    end

    context 'when the medium is not an image' do
      let(:video_medium) { create(:medium, media_type: :video, content_type: 'video/mp4') }

      it 'raises without creating a doc' do
        expect {
          described_class.new(
            project: project,
            medium: video_medium,
            user: user,
            attributes: { source: nil, sourcedb: nil, sourceid: nil }
          ).call
        }.to raise_error(ArgumentError, /image media/).and change(Doc, :count).by(0)
      end
    end

    context 'when the medium has no attached file' do
      let(:medium_without_file) { create(:medium) }

      it 'raises without creating a doc' do
        expect {
          described_class.new(
            project: project,
            medium: medium_without_file,
            user: user,
            attributes: { source: nil, sourcedb: nil, sourceid: nil }
          ).call
        }.to raise_error(ArgumentError, /no attached file/).and change(Doc, :count).by(0)
      end
    end
  end
end
