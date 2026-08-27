# Tracks a single attempt to generate the text (image caption, or audio/video transcript) for
# one Medium. It does not itself create or persist a Doc — DocGenerationFromMediaJob builds
# the Doc separately, from the text this attempt produces, so `status` reflects only whether
# generating that text succeeded, independent of whether a Doc/MediaTranscript ended up
# persisted. This is what lets "not yet processed" and "processing failed" be told apart,
# since neither one leaves any other record behind. A Medium may have more than one task over
# time (e.g. a retry after a failure); there is no uniqueness constraint on medium_id.
#
# This is a dedicated resource rather than an extension of Job because Job is a generic,
# cross-media background-job tracker: it belongs to an organization/Project (not a Medium),
# derives its state from begun_at/ended_at timestamps, tracks progress via num_items/num_dones,
# is user-deletable, and its #destroy bypasses ActiveRecord callbacks via a raw `self.delete`
# (so a `has_many ... dependent: :destroy` on Job would not even fire). Teaching Job to answer
# "what's the transcription status of this Medium" would require generalizing it with a
# polymorphic subject (subject_type/subject_id), spreading transcription-specific concerns
# into every other kind of Job.
#
# It is kept separate from MediaTranscript because that model represents the successful
# *output* of a transcription (the segments) and should only exist when there is real content
# to show. MediaTranscriptionTask represents the *attempt* itself, including states (pending,
# processing, failed) where no output exists at all.
class MediaTranscriptionTask < ApplicationRecord
  belongs_to :medium
  belongs_to :job, optional: true
  has_one :media_transcript, dependent: :nullify

  validates :status, presence: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    succeeded: 'succeeded',
    no_speech: 'no_speech',
    failed: 'failed'
  }

  # Wraps a transcription attempt, transitioning through processing -> succeeded/no_speech/failed
  # and re-raising any error from the block after recording it, so the caller doesn't need to
  # manage the task's status itself. Mirrors `transaction do ... end`. The block is expected to
  # return a [body, segments] tuple, as DocGenerationFromMedia#generate_transcript does. segments
  # is nil for media types that don't produce it (e.g. an image caption) — those always succeed.
  # An empty array means the medium does produce segments (audio/video) but none were detected,
  # which is classified as no_speech.
  def process
    processing!
    body, segments = yield
    no_speech_detected = segments.is_a?(Array) && segments.empty?
    no_speech_detected ? no_speech! : succeeded!
    [body, segments]
  rescue StandardError
    failed! unless succeeded? || no_speech?
    raise
  end
end
