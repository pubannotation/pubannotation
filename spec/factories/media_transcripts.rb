# frozen_string_literal: true

FactoryBot.define do
  factory :media_transcript do
    association :medium, media_type: :audio, content_type: 'audio/mpeg'
    media_transcription_task { association(:media_transcription_task, medium: medium) }
    segments do
      [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
      ]
    end
  end
end
