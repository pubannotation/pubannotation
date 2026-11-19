# The editor for splitting and merging a Doc's segments: its media and its segments' text, to point where to
# split one and at what playback time, or which to merge with the next one, saving them all at once, then going
# back to the doc's page it was opened from.
class SegmentationsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :authorize_segment_edit
  before_action :set_return_to

  # GET /docs/:doc_id/segmentation/edit
  def edit
  end

  # PATCH /docs/:doc_id/segmentation
  # Saves the segments as split and merged on the editor, given as JSON of their attributes, replacing all of
  # them (see MediaTranscript#resegment!), back on the doc's page. Back on the editor if they can't be saved.
  def update
    @media_transcript.resegment!(segments_param)

    redirect_to @back_path, notice: 'Segments were successfully saved.'
  rescue JSON::ParserError, ArgumentError, TypeError, ActiveRecord::RecordInvalid => e
    redirect_to edit_doc_segmentation_path(@doc, return_to: @return_to), alert: e.message
  end

  private

  # The segments as split and merged on the editor, sent as a JSON array of their attributes.
  def segments_param
    segments = JSON.parse(params.expect(segmentation: [:segments])[:segments], symbolize_names: true)
    return segments if segments.is_a?(Array) && segments.all?(Hash)

    raise ArgumentError, 'Segments must be sent as a JSON array of objects.'
  end

  def set_media_transcript
    @doc = Doc.find(params[:doc_id])
    return render_status_error(:not_found) unless @doc.segments_available?

    @media_transcript = @doc.media_transcript
  end

  def authorize_segment_edit
    render_status_error(:forbidden) unless @doc.segment_editable_by?(current_user)
  end

  # The doc's page the editor was opened from, kept through the editor to go back to, and where to go back:
  # there if it's on this site, since it's taken from the request, or else the doc's page.
  def set_return_to
    @return_to = params[:return_to].presence
    @back_path = url_from(@return_to) || doc_sourcedb_sourceid_show_path(@doc.sourcedb, @doc.sourceid)
  end
end
