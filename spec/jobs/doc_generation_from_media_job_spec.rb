# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocGenerationFromMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:attributes) { { sourcedb: 'Example', sourceid: '001' } }

  describe '#perform' do
    let(:text_generation) { instance_double(MediaTextGenerationService, call: 'A generated transcript.') }
    let(:doc_creation) { instance_double(MediaDocCreationService, save_doc: nil) }

    before do
      allow(MediaTextGenerationService).to receive(:new).and_return(text_generation)
      allow(MediaDocCreationService).to receive(:new).and_return(doc_creation)
    end

    context 'with an image medium' do
      let(:medium) { create(:medium, user: user, media_type: :image, content_type: 'image/png') }

      it 'delegates text generation to MediaTextGenerationService and doc creation to MediaDocCreationService' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        expect(MediaTextGenerationService).to have_received(:new).with(medium, caption_model: nil)
        expect(text_generation).to have_received(:call)
        expect(MediaDocCreationService).to have_received(:new).with(project:, medium:, user:, attributes:)
        expect(doc_creation).to have_received(:save_doc).with('A generated transcript.')
      end

      it 'creates a MediaTranscriptionTask and marks it succeeded' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(task).to be_present
        expect(task).to be_succeeded
      end

      it 'passes a given caption_model through to MediaTextGenerationService' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes, 'medgemma:4b')

        expect(MediaTextGenerationService).to have_received(:new).with(medium, caption_model: 'medgemma:4b')
      end
    end

    context 'with an audio medium' do
      let(:medium) { create(:medium, user: user, media_type: :audio, content_type: 'audio/mpeg') }

      it 'creates a MediaTranscriptionTask and marks it succeeded' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(task).to be_present
        expect(task).to be_succeeded
      end

      context 'when generating the text fails' do
        before do
          allow(text_generation).to receive(:call).and_raise(StandardError, 'transcription blew up')
        end

        it 'marks the task failed and re-raises' do
          expect {
            DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)
          }.to raise_error(StandardError, 'transcription blew up')

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_failed
        end
      end

      context 'when saving the doc fails after successfully generating text' do
        before do
          allow(doc_creation).to receive(:save_doc).and_raise(StandardError, 'doc save blew up')
        end

        it 'leaves the task succeeded and re-raises' do
          expect {
            DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)
          }.to raise_error(StandardError, 'doc save blew up')

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_succeeded
        end
      end
    end

    context 'with a video medium' do
      let(:medium) { create(:medium, user: user, media_type: :video, content_type: 'video/mp4') }

      it 'creates a MediaTranscriptionTask and marks it succeeded' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(task).to be_present
        expect(task).to be_succeeded
      end
    end
  end

  describe '#job_name' do
    it 'returns the correct name' do
      expect(DocGenerationFromMediaJob.new.job_name).to eq('Generate doc text from media')
    end
  end
end
