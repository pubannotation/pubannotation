# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaTranscriptionTask, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:media_transcription_task)).to be_valid
    end

    it 'requires a medium' do
      expect(build(:media_transcription_task, medium: nil)).not_to be_valid
    end

    it 'does not require a job' do
      expect(build(:media_transcription_task, job: nil)).to be_valid
    end

    it 'defaults to pending status' do
      expect(MediaTranscriptionTask.new.status).to eq('pending')
    end

    it 'rejects a status outside the defined enum' do
      expect { build(:media_transcription_task, status: 'bogus') }.to raise_error(ArgumentError)
    end

    it 'rejects a nil status' do
      expect(build(:media_transcription_task, status: nil)).not_to be_valid
    end

    it 'accepts an image medium' do
      medium = create(:medium, media_type: :image, content_type: 'image/jpeg')

      expect(build(:media_transcription_task, medium: medium)).to be_valid
    end

    it 'accepts an audio medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

      expect(build(:media_transcription_task, medium: medium)).to be_valid
    end

    it 'accepts a video medium' do
      medium = create(:medium, media_type: :video, content_type: 'video/mp4')

      expect(build(:media_transcription_task, medium: medium)).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      media_transcription_task = create(:media_transcription_task, medium: medium)

      expect(media_transcription_task.medium).to eq(medium)
    end

    it 'belongs to a job' do
      job = create(:job)
      media_transcription_task = create(:media_transcription_task, job: job)

      expect(media_transcription_task.job).to eq(job)
    end

    it 'allows multiple tasks for the same medium' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
      create(:media_transcription_task, medium: medium)

      expect(build(:media_transcription_task, medium: medium)).to be_valid
    end

    it 'does not destroy its media_transcript when destroyed, but nullifies the reference' do
      task = create(:media_transcription_task)
      media_transcript = create(:media_transcript, media_transcription_task: task, medium: task.medium)

      task.destroy

      expect(media_transcript.reload.media_transcription_task_id).to be_nil
    end
  end

  describe '#process' do
    it 'transitions to processing then succeeded when segments are present, and returns the block value' do
      task = create(:media_transcription_task)
      segments = [{ 'text' => 'hi', 'start_ms' => 0, 'end_ms' => 100 }]

      result = task.process { ['transcribed text', segments] }

      expect(result).to eq(['transcribed text', segments])
      expect(task).to be_succeeded
    end

    it 'transitions to no_speech when the returned segments are an empty array' do
      task = create(:media_transcription_task)

      result = task.process { ['', []] }

      expect(result).to eq(['', []])
      expect(task).to be_no_speech
    end

    it 'transitions to succeeded when segments are nil (e.g. an image caption)' do
      task = create(:media_transcription_task)

      result = task.process { ['a caption', nil] }

      expect(result).to eq(['a caption', nil])
      expect(task).to be_succeeded
    end

    it 'transitions to failed and re-raises when the block raises' do
      task = create(:media_transcription_task)

      expect {
        task.process { raise StandardError, 'boom' }
      }.to raise_error(StandardError, 'boom')

      expect(task).to be_failed
    end

    it 'does not overwrite an already-succeeded status if failed! itself raises' do
      task = create(:media_transcription_task)

      expect {
        task.process do
          task.update!(status: 'succeeded')
          raise StandardError, 'boom after succeeding'
        end
      }.to raise_error(StandardError, 'boom after succeeding')

      expect(task.reload).to be_succeeded
    end

    it 'does not overwrite an already-no_speech status if failed! itself raises' do
      task = create(:media_transcription_task)

      expect {
        task.process do
          task.update!(status: 'no_speech')
          raise StandardError, 'boom after no_speech'
        end
      }.to raise_error(StandardError, 'boom after no_speech')

      expect(task.reload).to be_no_speech
    end
  end

  describe 'status' do
    %w[pending processing succeeded no_speech failed].each do |status|
      it "supports the #{status} status" do
        media_transcription_task = build(:media_transcription_task, status: status)

        expect(media_transcription_task.status).to eq(status)
        expect(media_transcription_task.public_send("#{status}?")).to be true
      end
    end
  end
end
