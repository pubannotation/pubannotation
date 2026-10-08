# Lists the segments of a Doc's MediaTranscript, editing the text of one of them in a dialog.
class SegmentsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :set_segment, only: :update

  # GET /docs/:doc_id/segments
  def index
  end

  # PATCH /docs/:doc_id/segments/:index
  def update
    @text = params.expect(segment: [:text])[:text]
    @media_transcript.set_segment_text(@index, @text)
    @media_transcript.save!

    redirect_to doc_segments_path(@doc), notice: 'Segment text was successfully updated.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    # Reopens the dialog with the entered text, for it to be fixed and saved again.
    flash.now[:notice] = e.message
    @media_transcript.reload
    render :index, status: :unprocessable_content
  end

  private

  def set_media_transcript
    @doc = Doc.find(params[:doc_id])
    return render_status_error(:forbidden) unless @doc.updatable_for?(current_user)

    @media_transcript = @doc.media_transcript if @doc.media_transcript&.segments.present?
    render_status_error(:not_found) unless @media_transcript
  end

  def set_segment
    @index = Integer(params[:index], exception: false)
    @segment = @media_transcript.segments[@index] if @index&.between?(0, @media_transcript.segments.size - 1)
    render_status_error(:not_found) unless @segment
  end
end
