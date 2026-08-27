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
  let(:audio_medium) do
    medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')),
      filename: 'test_audio.mp3',
      content_type: 'audio/mpeg'
    )
    medium
  end
  let(:video_medium) do
    medium = create(:medium, media_type: :video, content_type: 'video/mp4')
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4')),
      filename: 'test_video.mp4',
      content_type: 'video/mp4'
    )
    medium
  end

  describe 'generating a doc from media' do
    context 'with a valid image medium' do
      before do
        allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))
      end

      it 'creates a doc with the generated caption, linked to the medium and the project' do
        service = described_class.new(
          project: project,
          medium: image_medium,
          user: user,
          attributes: { source: nil, sourcedb: 'Example', sourceid: '001' }
        )
        doc = service.save_doc(service.generate_transcript)

        expect(doc).to be_persisted
        expect(doc.body).to eq('A generated caption.')
        expect(doc.sourcedb).to eq("Example@#{user.username}")
        expect(doc.sourceid).to eq('001')
        expect(doc.medium).to eq(image_medium)
        expect(project.docs).to include(doc)
      end
    end

    context 'with a valid audio medium' do
      before do
        allow(AudioTranscriptionService).to receive(:new).and_return(instance_double(AudioTranscriptionService, call: 'A generated transcript.'))
      end

      it 'creates a doc with the generated transcript, linked to the medium and the project' do
        service = described_class.new(
          project: project,
          medium: audio_medium,
          user: user,
          attributes: { source: nil, sourcedb: 'Example', sourceid: '002' }
        )
        doc = service.save_doc(service.generate_transcript)

        expect(doc).to be_persisted
        expect(doc.body).to eq('A generated transcript.')
        expect(doc.sourcedb).to eq("Example@#{user.username}")
        expect(doc.sourceid).to eq('002')
        expect(doc.medium).to eq(audio_medium)
        expect(project.docs).to include(doc)
      end
    end

    context 'with a valid video medium' do
      before do
        allow(VideoTranscriptionService).to receive(:new).and_return(instance_double(VideoTranscriptionService, call: 'A generated transcript.'))
      end

      it 'creates a doc with the transcript generated from the video' do
        service = described_class.new(
          project: project,
          medium: video_medium,
          user: user,
          attributes: { source: nil, sourcedb: 'Example', sourceid: '003' }
        )
        doc = service.save_doc(service.generate_transcript)

        expect(doc).to be_persisted
        expect(doc.body).to eq('A generated transcript.')
        expect(doc.sourcedb).to eq("Example@#{user.username}")
        expect(doc.sourceid).to eq('003')
        expect(doc.medium).to eq(video_medium)
        expect(project.docs).to include(doc)
      end
    end

    context 'when the medium has an unsupported media type' do
      it 'raises without creating a doc' do
        medium = image_medium
        allow(medium).to receive_messages(image?: false, audio?: false, video?: false, media_type: nil)

        expect {
          described_class.new(
            project: project,
            medium: medium,
            user: user,
            attributes: { source: nil, sourcedb: nil, sourceid: nil }
          ).generate_transcript
        }.to raise_error(ArgumentError, /Unsupported media type/).and change(Doc, :count).by(0)
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
          ).generate_transcript
        }.to raise_error(ArgumentError, /no attached file/).and change(Doc, :count).by(0)
      end
    end
  end
end
