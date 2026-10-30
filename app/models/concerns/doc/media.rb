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

  class_methods do
    # A body written by hand for a doc with `medium`. An audio/video doc's body is what was said, joined from its
    # segments (see MediaTranscript#speech_text), so it's spaced as a segment's text is; any other is left as it is.
    def written_body(medium, text)
      medium&.transcribable? ? TextNormalizable.normalize_inline_text(text) : text
    end
  end

  # Sets the body to `text` written by hand, as .written_body has it. Left as it is when unchanged, as the edit
  # form submits it back with other changes, so a line break its segments set isn't put on one line.
  def assign_written_body(text)
    self.body = text
    self.body = Doc.written_body(medium, body) if body_changed?
  end

  # Whether `current_user` can edit the segments of this doc's media transcript.
  def segment_editable_by?(current_user)
    segments_available? && updatable_for?(current_user)
  end

  # Whether the transcript has segments; media access is checked by the controller.
  def segments_available?
    media_transcript&.segmented?
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
    return unless media_transcript.transcribed_by_whisper?
    return if body_following_transcript?

    errors.add(:base, 'Body cannot be changed directly for a document transcribed by Whisper; edit its segments instead')
  end

  # The body following the transcript, once its segments changed (see MediaTranscript#sync_doc_body), so
  # already as the transcript has it, e.g. with the line breaks its segments set.
  def body_following_transcript?
    media_transcript&.text == body
  end

  # An audio/video doc's body is what was said, to be highlighted as it's played, so it can't be only a
  # non-speech label such as "(music)" (or empty, as its segments would make it with no speech left).
  def body_has_speech
    errors.add(:body, 'must have speech for a document with audio or video') if NonSpeechTextMatcher.match?(body)
  end

  def sync_media_transcript_with_body
    # Already in step when the body followed the transcript, e.g. after its segments changed.
    return if media_transcript.nil? || media_transcript.text == body

    media_transcript.replace_text!(body)
  end
end
