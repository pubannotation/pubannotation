# frozen_string_literal: true

FactoryBot.define do
  factory :media_transcript do
    # Built with its attributes, so its text is derived from its segments as it's initialized.
    initialize_with { new(**attributes) }

    association :medium, media_type: :audio, content_type: 'audio/mpeg'
    media_transcription_task { nil }
    segments do
      [
        FactoryBot.build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
        FactoryBot.build(:segment, :without_transcript, sort_order: 1, text: 'world', start_ms: 300, end_ms: 600)
      ]
    end

    trait :with_task do
      media_transcription_task { association(:media_transcription_task, medium: medium) }
    end
  end
end
