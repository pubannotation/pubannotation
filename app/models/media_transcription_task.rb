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
# It is kept separate from MediaTranscript because that model represents a transcription
# attempt that actually ran to completion — even a blank/no-speech one — while
# MediaTranscriptionTask represents the attempt itself, including states (pending, processing,
# failed) where generation didn't complete at all and no MediaTranscript exists yet.
class MediaTranscriptionTask < ApplicationRecord
  belongs_to :medium
  belongs_to :job, optional: true
  has_one :media_transcript, dependent: :nullify

  validates :status, presence: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    succeeded: 'succeeded',
    failed: 'failed'
  }

  # Wraps a transcription attempt, transitioning through processing -> succeeded/failed and
  # re-raising any error from the block after recording it, so the caller doesn't need to
  # manage the task's status itself. Mirrors `transaction do ... end`. Whether the returned
  # MediaTranscript actually has any content (e.g. no speech detected, or a blank image
  # caption) is not this task's concern — that's for the caller to decide, since it's a
  # property of the transcript, not of whether generating it succeeded.
  def process
    processing!
    result = yield
    succeeded!
    result
  rescue StandardError
    failed! unless succeeded?
    raise
  end
end
