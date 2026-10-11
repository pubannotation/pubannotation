class AudioSegmentDenotationService
  # Marks a Denotation as corresponding to a spoken segment of the media, rather than a real
  # semantic annotation. Its span is what selects it for playback-position highlighting; obj is
  # otherwise unused (TextAE's selectDenotation/focusDenotation work independently of obj).
  DENOTATION_OBJ = 'AudioSegment'.freeze

  # Creates one Denotation per speech segment of media_transcript in doc, which is expected to be
  # already added to project.
  #
  # insert_all (not Denotation.create! in a loop) so it's one INSERT, but that skips
  # after_create's counter callbacks — replicated manually below instead. hids are numbered
  # locally rather than via Denotation.new_id, which uses process-shared state.
  def self.call(project, doc, media_transcript)
    spans = media_transcript.speech_segment_spans
    return if spans.empty?

    records = spans.map.with_index(1) do |span, index|
      {
        hid: "#{Denotation::HID_PREFIX}#{index}",
        begin: span[:begin],
        end: span[:end],
        obj: DENOTATION_OBJ,
        project_id: project.id,
        doc_id: doc.id
      }
    end

    Denotation.insert_all(records, record_timestamps: true)

    ProjectDoc.find_by!(project:, doc:).increment!(:denotations_num, records.size)
    doc.increment!(:denotations_num, records.size)
    project.increment!(:denotations_num, records.size)
    project.update_updated_at
  end
end
