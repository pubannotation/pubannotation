class MediaDocCreationService
  # Marks a Denotation as corresponding to a spoken segment of the media, rather than a real
  # semantic annotation. Its span is what selects it for playback-position highlighting; obj is
  # otherwise unused (TextAE's selectDenotation/focusDenotation work independently of obj).
  DENOTATION_OBJ = 'AudioSegment'.freeze

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
      create_segment_denotations!(project, doc, media_transcript)
    end

    doc
  end

  # insert_all (not Denotation.create! in a loop) so it's one INSERT, but that skips
  # after_create's counter callbacks — replicated manually below instead. hids are numbered
  # locally rather than via Denotation.new_id, which uses process-shared state.
  def self.create_segment_denotations!(project, doc, media_transcript)
    spans = media_transcript.speech_segment_spans
    return if spans.empty?

    records = spans.map.with_index(1) do |span, index|
      { hid: "#{Denotation::HID_PREFIX}#{index}", begin: span['begin'], end: span['end'],
        obj: DENOTATION_OBJ, project_id: project.id, doc_id: doc.id }
    end

    Denotation.insert_all(records, record_timestamps: true)

    ProjectDoc.find_by(project_id: project.id, doc_id: doc.id)&.increment!(:denotations_num, records.size)
    doc.increment!(:denotations_num, records.size)
    project.increment!(:denotations_num, records.size)
    project.update_updated_at
  end
  private_class_method :create_segment_denotations!
end
