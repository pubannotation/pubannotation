# Tracks a single attempt to transcribe one Medium (audio/video only; images are captioned,
# not transcribed, and have no task). `status` is the machine-readable outcome of that attempt
# (pending/processing/succeeded/no_speech/failed), independent of whether the attempt produced
# a persisted Doc/MediaTranscript. This is what lets "not yet processed" and "processing
# failed" be told apart, since neither one leaves any other record behind. A Medium may have
# more than one task over time (e.g. a retry after a failure); there is no uniqueness
# constraint on medium_id.
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

  validates :status, presence: true
  validate :medium_must_be_audio_or_video

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    succeeded: 'succeeded',
    no_speech: 'no_speech',
    failed: 'failed'
  }

  private

  def medium_must_be_audio_or_video
    return unless medium

    errors.add(:medium, 'must be audio or video') unless medium.transcribable?
  end
end
