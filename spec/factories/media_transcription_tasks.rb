# frozen_string_literal: true

FactoryBot.define do
  factory :media_transcription_task do
    association :medium, media_type: :audio, content_type: 'audio/mpeg'
    status { 'pending' }
  end
end
