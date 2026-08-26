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

    it 'rejects a medium whose media_type is image' do
      medium = create(:medium, media_type: :image, content_type: 'image/jpeg')

      expect(build(:media_transcription_task, medium: medium)).not_to be_valid
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
