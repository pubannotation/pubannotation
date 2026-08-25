# frozen_string_literal: true

FactoryBot.define do
  factory :media_transcript do
    doc { association(:doc, medium: association(:medium, media_type: :audio, content_type: 'audio/mpeg')) }
    segments do
      [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
      ]
    end
  end
end
