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
    if @doc.segments_listable_by?(current_user)
      @media_transcript = @doc.media_transcript
    else
      # Refused as not allowed, or as having no segments to list.
      render_status_error(@doc.updatable_for?(current_user) ? :not_found : :forbidden)
    end
  end
end
