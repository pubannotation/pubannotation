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

  # PATCH /docs/:doc_id/segments/:index
  def update
    @text = segment_text_param
    # Reloads and locks the transcript, so a concurrent edit of another segment isn't overwritten.
    @media_transcript.with_lock do
      @media_transcript.set_segment_text(@index, @text)
      @media_transcript.save!
    end

    redirect_to doc_segments_path(@doc), notice: 'Segment text was successfully updated.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    # Reopens the dialog with the entered text and the error, for it to be fixed and saved again.
    @error = e.message
    @media_transcript.reload
    render :index, status: :unprocessable_content
  end

  private

  def segment_text_param
    # Browsers submit a textarea's line breaks as CRLF, as DocsController#update also normalizes.
    params.expect(segment: [:text])[:text]&.gsub("\r\n", "\n")
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

  def set_segment
    @index = Integer(params[:index], exception: false)
    @segment = @media_transcript.segments[@index] if @index&.between?(0, @media_transcript.segments.size - 1)
    render_status_error(:not_found) unless @segment
  end
end
