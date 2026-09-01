# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocGenerationFromMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:attributes) { { sourcedb: 'Example', sourceid: '001' } }
  let(:segments) { [{ 'text' => 'A generated transcript.', 'start_ms' => 0, 'end_ms' => 1000 }] }
  let(:generation) { instance_double(DocGenerationFromMedia, generate_transcript: ['A generated transcript.', segments], save_doc: nil) }

  describe '#perform' do
    before do
      allow(DocGenerationFromMedia).to receive(:new).and_return(generation)
    end

    context 'with an image medium' do
      let(:medium) { create(:medium, user: user, media_type: :image, content_type: 'image/png') }
      let(:generation) { instance_double(DocGenerationFromMedia, generate_transcript: ['A generated caption.', nil], save_doc: nil) }

      it 'delegates to DocGenerationFromMedia with the given project, medium, user and attributes' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(DocGenerationFromMedia).to have_received(:new).with(project:, medium:, user:, attributes:)
        expect(generation).to have_received(:generate_transcript)
        expect(generation).to have_received(:save_doc).with('A generated caption.', nil, media_transcription_task: task)
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

      it 'saves the doc with the transcript and segments' do
        DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

        task = MediaTranscriptionTask.find_by(medium: medium)
        expect(generation).to have_received(:save_doc).with('A generated transcript.', segments, media_transcription_task: task)
      end

      context 'when generating the transcript fails' do
        before do
          allow(generation).to receive(:generate_transcript).and_raise(StandardError, 'transcription blew up')
        end

        it 'marks the task failed and re-raises' do
          expect {
            DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)
          }.to raise_error(StandardError, 'transcription blew up')

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_failed
        end
      end

      context 'when saving the doc fails after a successful transcript' do
        before do
          allow(generation).to receive(:save_doc).and_raise(StandardError, 'doc save blew up')
        end

        it 'leaves the task succeeded and re-raises' do
          expect {
            DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)
          }.to raise_error(StandardError, 'doc save blew up')

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_succeeded
        end
      end

      context 'when no segments are returned' do
        let(:generation) { instance_double(DocGenerationFromMedia, generate_transcript: ['', []], save_doc: nil, save_transcript: nil) }

        it 'marks the task no_speech, saves the transcript, and does not save a doc' do
          DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_no_speech
          expect(generation).to have_received(:save_transcript).with([], media_transcription_task: task)
          expect(generation).not_to have_received(:save_doc)
        end
      end

      context 'when only non-speech segments are returned' do
        let(:non_speech_segments) { [{ 'text' => '(applause)', 'start_ms' => 0, 'end_ms' => 2000 }] }
        let(:generation) do
          instance_double(DocGenerationFromMedia, generate_transcript: ['(applause)', non_speech_segments], save_doc: nil,
                                                    save_transcript: nil)
        end

        it 'marks the task no_speech, saves the transcript, and does not save a doc' do
          DocGenerationFromMediaJob.perform_now(project, medium, user, attributes)

          task = MediaTranscriptionTask.find_by(medium: medium)
          expect(task).to be_no_speech
          expect(generation).to have_received(:save_transcript).with(non_speech_segments, media_transcription_task: task)
          expect(generation).not_to have_received(:save_doc)
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
