# Lists the segments of a Doc's MediaTranscript, editing the text of one of them in a dialog, and whether a
# line break follows one with its checkbox.
class SegmentsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :authorize_segment_edit, only: %i[update line_break]
  before_action :set_segment, only: %i[update line_break]

  # GET /docs/:doc_id/segments
  def index
  end

  # PATCH /docs/:doc_id/segments/:id
  # The segment's text, from the dialog.
  def update
    @text = segment_text_param
    change_segments { @media_transcript.set_segment_text(@segment, @text) }

    redirect_to doc_segments_path(@doc), notice: 'Segment text was successfully updated.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    # Reopens the dialog with the entered text and the error, for it to be fixed and saved again.
    @error = e.message
    @media_transcript.reload
    render :index, status: :unprocessable_content
  end

  # PATCH /docs/:doc_id/segments/:id/line_break
  # Whether a line break follows the segment, from its checkbox.
  def line_break
    change_segments { @media_transcript.set_segment_line_break_after(@segment, segment_line_break_after_param) }

    redirect_to doc_segments_path(@doc), notice: 'Line break was successfully updated.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    # A checkbox's change has nothing to fix in a dialog, so it goes back to the list with the error.
    redirect_to doc_segments_path(@doc), alert: e.message
  end

  private

  def segment_text_param
    params.expect(segment: [:text])[:text]
  end

  def segment_line_break_after_param
    params.expect(segment: [:line_break_after])[:line_break_after]
  end

  # Reloads and locks the transcript, so a concurrent edit of another segment isn't overwritten.
  def change_segments
    @media_transcript.with_lock do
      yield
      @media_transcript.save!
    end
  end

  def set_media_transcript
    @doc = Doc.find(params[:doc_id])
    return render_status_error(:not_found) unless @doc.segment_listable_by?(current_user)

    @media_transcript = @doc.media_transcript
    @editable = @doc.segment_editable_by?(current_user)
  end

  def authorize_segment_edit
    render_status_error(:forbidden) unless @editable
  end

  # By id rather than position, so a segment deleted or split since the page was loaded isn't mistaken for
  # another one now at its position.
  def set_segment
    @segment = @media_transcript.segments.find(params[:id])
    @index = @media_transcript.segments.index(@segment)
  end
end
