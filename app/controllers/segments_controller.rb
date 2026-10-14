# Lists the segments of a Doc's MediaTranscript.
class SegmentsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript

  # GET /docs/:doc_id/segments
  def index
  end

  private

  def set_media_transcript
    @doc = Doc.find(params[:doc_id])
    return render_status_error(:forbidden) unless @doc.updatable_for?(current_user)

    @media_transcript = @doc.media_transcript if @doc.media_transcript&.segments.present?
    render_status_error(:not_found) unless @media_transcript
  end
end
