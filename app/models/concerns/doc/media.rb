# frozen_string_literal: true

module Doc::Media
  extend ActiveSupport::Concern

  included do
    belongs_to :medium, optional: true
    has_one :media_transcript, dependent: :destroy

    before_validation :flatten_speech_body, if: -> { medium&.transcribable? && will_save_change_to_body? }

    validate :media_reference_immutable, on: :update
    validate :body_immutable_when_transcribed_by_whisper, on: :update
    validate :body_has_speech, if: -> { medium&.transcribable? }
    after_update :sync_media_transcript_with_body, if: :saved_change_to_body?
  end

  # Whether `current_user` can edit the segments of this doc's media transcript.
  def segment_editable_by?(current_user)
    segment_listable_by?(current_user) && updatable_for?(current_user)
  end

  # For a doc registered by hand with an audio/video medium, so its detail page can highlight and seek it
  # like a transcribed doc: with no timing to go on, its whole body becomes a single segment spanning the
  # media's full duration. Returns the transcript.
  def create_media_transcript_from_body!
    raise ArgumentError, "Specified media can't get a transcript." unless medium&.transcribable?

    # text is set explicitly, since deriving it would drop a body that looks like a Whisper
    # non-speech label (e.g. "(music)").
    MediaTranscript.create!(
      medium:,
      doc: self,
      text: body,
      segments: [Segment.new(sort_order: 0, text: body, start_ms: 0, end_ms: medium.duration_ms)]
    )
  end

  # Anyone can, given segments; access to media, while it's being tried out, is checked by the controller.
  def segment_listable_by?(current_user)
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
    # The body following the transcript, once its segments changed (see MediaTranscript#sync_doc_body).
    return if media_transcript.text == body

    errors.add(:base, 'Body cannot be changed directly for a document transcribed by Whisper; edit its segments instead')
  end

  # An audio/video doc's body is what was said, joined from its segments with a space (see
  # MediaTranscript#speech_text), so one written by hand is spaced as a segment's text is.
  def flatten_speech_body
    self.body = TextNormalizable.normalize_inline_text(body)
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
