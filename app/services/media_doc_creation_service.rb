class MediaDocCreationService
  # Marks a Block as corresponding to a spoken segment of the media, kept apart from the denotations
  # of real semantic annotations. Its span is what selects it for playback-position highlighting.
  BLOCK_OBJ = 'AudioSegment'.freeze

  # media_transcript is expected to already be persisted (with doc: nil) by the caller.
  def self.call(project, medium, user, attributes, media_transcript)
    hdoc = Doc.hdoc_normalize!(
      {
        **attributes,
        username: user.username,
        body: media_transcript.text,
        medium_id: medium.id
      },
      user,
      user.root?
    )

    # Doc.create! directly, rather than Doc.store_hdoc!, since store_hdoc! opens its own
    # isolation: :read_committed transaction — which raises if opened while already inside the
    # transaction below. hdoc never has :divisions/:typesettings here (hdoc_normalize! doesn't
    # add them), so store_hdoc!'s handling of those is not needed either.
    doc = nil
    ActiveRecord::Base.transaction do
      doc = Doc.create!(
        body: hdoc[:body],
        sourcedb: hdoc[:sourcedb],
        sourceid: hdoc[:sourceid],
        source: hdoc[:source],
        medium_id: hdoc[:medium_id]
      )
      media_transcript.update!(doc:)
      project.add_doc!(doc)
      create_segment_blocks!(project, doc, media_transcript)
    end

    doc
  end

  # Creates, in `project`, a Block for each speech segment of `media_transcript` on `doc`, which is expected
  # to be already added to `project`. Also for a doc registered by hand (see ManualDocPlaybackService).
  def self.create_segment_blocks!(project, doc, media_transcript)
    blocks = media_transcript.speech_segment_spans.map.with_index(1) do |span, index|
      { id: "#{Block::HID_PREFIX}#{index}", span: span.slice(:begin, :end), obj: BLOCK_OBJ }
    end
    project.instantiate_and_save_annotations({ blocks: }, doc) if blocks.any?
  end
end
