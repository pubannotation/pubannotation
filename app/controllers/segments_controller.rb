# Lists the segments of a Doc's MediaTranscript, editing the text of one of them in a dialog.
class SegmentsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :authorize_segment_edit, only: :update
  before_action :set_segment, only: :update

  # GET /docs/:doc_id/segments
  def index
  end

  # PATCH /docs/:doc_id/segments/:id
  # Takes the segment's text (from the dialog) or whether a line break follows it (from its checkbox).
  def update
    attributes = segment_params
    @text = attributes[:text]
    # Reloads and locks the transcript, so a concurrent edit of another segment isn't overwritten.
    @media_transcript.with_lock do
      @media_transcript.set_segment_text(@segment, @text) if attributes.key?(:text)
      @media_transcript.set_segment_line_break_after(@segment, attributes[:line_break_after]) if attributes.key?(:line_break_after)
      @media_transcript.save!
    end

    redirect_to doc_segments_path(@doc), notice: 'Segment was successfully updated.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    if attributes.key?(:text)
      # Reopens the dialog with the entered text and the error, for it to be fixed and saved again.
      @error = e.message
      @media_transcript.reload
      render :index, status: :unprocessable_content
    else
      # A checkbox's change has nothing to fix in a dialog, so it goes back to the list with the error.
      redirect_to doc_segments_path(@doc), alert: e.message
    end
  end

  private

  def segment_params
    params.expect(segment: %i[text line_break_after])
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
