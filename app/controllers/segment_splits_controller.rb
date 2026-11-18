# The editor for splitting a Doc's segments: its media and its segments' text, to point where to split
# one and at what playback time, saving the splits all at once.
class SegmentSplitsController < ApplicationController
  include MediaAccessAuthorizationConcern

  before_action :authenticate_user!
  before_action :authorize_media_access!
  before_action :set_media_transcript
  before_action :authorize_segment_edit

  # GET /docs/:doc_id/segment_split/edit
  def edit
  end

  # PATCH /docs/:doc_id/segment_split
  # Saves the segments as split on the editor, given as JSON of their attributes, replacing all of them (see
  # MediaTranscript#resegment!), back on the editor.
  def update
    @media_transcript.resegment!(segments_param)

    redirect_to edit_doc_segment_split_path(@doc), notice: 'Segments were successfully saved.'
  rescue JSON::ParserError, ArgumentError, TypeError, ActiveRecord::RecordInvalid => e
    redirect_to edit_doc_segment_split_path(@doc), alert: e.message
  end

  private

  # The segments as split on the editor, sent as a JSON array of their attributes.
  def segments_param
    segments = JSON.parse(params.expect(segment_split: [:segments])[:segments], symbolize_names: true)
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
end
