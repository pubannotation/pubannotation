# The editor for splitting a Doc's segments: its media and its segments' text, to point where to split
# one and at what playback time.
class SegmentSplitsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :authorize_segment_edit

  # GET /docs/:doc_id/segment_split/edit
  def edit
  end

  private

  def set_media_transcript
    @doc = Doc.find(params[:doc_id])
    return render_status_error(:not_found) unless @doc.segments_available?

    @media_transcript = @doc.media_transcript
  end

  def authorize_segment_edit
    render_status_error(:forbidden) unless @doc.segment_editable_by?(current_user)
  end
end
