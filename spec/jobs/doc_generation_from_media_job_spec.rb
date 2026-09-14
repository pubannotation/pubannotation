# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocGenerationFromMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:attributes) { { sourcedb: 'Example', sourceid: '001' } }
  let(:segments) { [{ 'text' => 'A generated transcript.', 'start_ms' => 0, 'end_ms' => 1000 }] }
  let(:generated_media_transcript) { MediaTranscript.new(medium:, text: 'A generated transcript.', segments:) }
  let(:text_generation) { instance_double(MediaTextGenerationService, call: generated_media_transcript) }

  describe '#perform' do
    before do
      allow(MediaTextGenerationService).to receive(:new).and_return(text_generation)
      allow(MediaDocCreationService).to receive(:call)
    end

    context 'with an image medium' do
      let(:medium) { create(:medium, user: user, media_type: :image, content_type: 'image/png') }
      let(:generated_media_transcript) { MediaTranscript.new(medium:, text: 'A generated caption.', segments: []) }

      it 'persists the transcript returned by MediaTextGenerationService, linked to the task' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        media_transcript = MediaTranscript.find_by(medium: medium)
        expect(media_transcript).to be_present
        expect(media_transcript.text).to eq('A generated caption.')
        expect(media_transcript.segments).to eq([])
        expect(media_transcript.media_transcription_task).to eq(task)
      end

      it 'delegates doc creation to MediaDocCreationService with the created transcript' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        media_transcript = MediaTranscript.find_by(medium: medium)
        expect(MediaTextGenerationService).to have_received(:new).with(medium)
        expect(MediaDocCreationService).to have_received(:call).with(project, medium, user, attributes, media_transcript)
      end

      it 'creates a MediaTranscriptionTask and marks it succeeded' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(task).to be_present
        expect(task).to be_succeeded
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

      it 'persists the transcript returned by MediaTextGenerationService, linked to the task' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        media_transcript = MediaTranscript.find_by(medium: medium)
        expect(media_transcript.text).to eq('A generated transcript.')
        expect(media_transcript.segments).to eq(segments)
        expect(media_transcript.media_transcription_task).to eq(task)
      end

      it 'delegates doc creation to MediaDocCreationService with the created transcript' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        media_transcript = MediaTranscript.find_by(medium: medium)
        expect(MediaDocCreationService).to have_received(:call).with(project, medium, user, attributes, media_transcript)
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
          allow(MediaDocCreationService).to receive(:call).and_raise(StandardError, 'doc save blew up')
        end

        it 'leaves the task succeeded and re-raises' do
          expect {
            DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)
          }.to raise_error(StandardError, 'doc save blew up')

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_succeeded
        end
      end

      context 'when the generated transcript has no speech' do
        let(:generated_media_transcript) { MediaTranscript.new(medium:, text: '', segments: []) }

        it 'marks the task succeeded, persists the transcript, but does not create a doc' do
          DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

          task = MediaTranscriptionTask.find_by(medium: medium)
          media_transcript = MediaTranscript.find_by(medium: medium)
          expect(task).to be_succeeded
          expect(media_transcript).to be_present
          expect(MediaDocCreationService).not_to have_received(:call)
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
