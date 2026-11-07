# frozen_string_literal: true

module Doc::Media
  extend ActiveSupport::Concern

  included do
    belongs_to :medium, optional: true
    has_one :media_transcript, dependent: :destroy

    validate :media_reference_immutable, on: :update
    validate :body_immutable_when_transcribed_by_whisper, on: :update
    validate :body_has_speech, if: -> { medium&.transcribable? }
    after_update :sync_media_transcript_with_body, if: :saved_change_to_body?
  end

  # Preserve an unchanged body, including line breaks set by its segments.
  def assign_written_body(text)
    self.body = text
    self.body = medium.written_doc_body(body) if body_changed? && medium
  end

  # Whether `current_user` can edit the segments of this doc's media transcript.
  def segment_editable_by?(current_user)
    segments_available? && updatable_for?(current_user)
  end

  # Whether the transcript has segments; media access is checked by the controller.
  def segments_available?
    media_transcript&.segmented?
  end

  # media_transcript's speech segment spans, fit to this Doc's body: segments can run past a body
  # edited after they were transcribed, so those past its end are dropped and the one running
  # past it is cut.
  def speech_segment_spans
    return [] unless media_transcript

    media_transcript.speech_segment_spans.filter_map do |span|
      span.merge(end: [span[:end], body.length].min) if span[:begin] < body.length
    end
  end

  private

  def media_reference_immutable
    if medium_id_changed?
      errors.add(:base, 'Media reference cannot be changed after creation')
    end
  end

  # A transcript not from Whisper follows the body instead (see #sync_media_transcript_with_body).
  def body_immutable_when_transcribed_by_whisper
    return unless will_save_change_to_body?

    return unless media_transcript
    return if media_transcript.allows_doc_body?(body)

    errors.add(:base, 'Body cannot be changed directly for a document transcribed by Whisper; edit its segments instead')
  end

  # An audio/video doc's body is what was said, to be highlighted as it's played, so it can't be only a
  # non-speech label such as "(music)" (or empty, as its segments would make it with no speech left).
  def body_has_speech
    errors.add(:body, 'must have speech for a document with audio or video') if NonSpeechTextMatcher.match?(body)
  end

  def sync_media_transcript_with_body
    media_transcript&.sync_text!(body)
  end
end
