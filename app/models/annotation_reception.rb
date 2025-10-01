# frozen_string_literal: true

# Acceptance window for Annotator-created annotations
class AnnotationReception < ApplicationRecord
  belongs_to :annotator
  belongs_to :project
  belongs_to :job

  validates :annotator_id, presence: true
  validates :project_id, presence: true

  def process_annotation!(annotations_collection)
    hdoc_metadata.map!(&:deep_symbolize_keys)

    annotations_collection.each_with_index do |annotations, i|
      raise RuntimeError, "Annotation result is not a valid JSON object." unless annotations.is_a?(Hash)

      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)

      hdoc_info = hdoc_metadata[i]
      symbolized_options = options.deep_symbolize_keys.merge(span: hdoc_info[:span])

      # When requesting annotation for a text that exceeds the Annotator's limit, split the request into sections.
      # At that time, the range requested by dividing the text is stored as a span parameter in hdoc_metadata.
      if symbolized_options[:span].present?
        messages = project.save_annotations!(annotations, Doc.find(hdoc_info[:docid]), symbolized_options)
        messages.each do |m|
          m = { body: m } if m.is_a?(String)
          job.add_message(m)
        end
      else
        messages = process_single_annotation_alignment(project, annotations, symbolized_options, job)
        messages.each { job.add_message it }
      end
    end

    job.increment!(:num_dones)
    job.finish!
  end

  private

  def process_single_annotation_alignment(project, annotations, options, job)
    warnings = []

    # Find document for the annotation
    doc = project.docs.find_by(sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid])
    unless doc
      return [{ sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], body: "Could not find the document" }]
    end

    # Skip annotations based on mode if needed
    if options[:mode] == 'skip'
      project_doc = ProjectDoc.find_by(project_id: project.id, doc_id: doc.id)
      if project_doc&.denotations_num != 0
        return [] # Skip if annotations already exist
      end
    end

    # Get reference text for alignment
    ref_text = doc&.original_body || doc.body

    # Process annotation if it has denotations or blocks
    if annotations[:denotations].present? || annotations[:blocks].present?
      begin
        # Create aligner and perform alignment
        aligner = Aligners.new(ref_text, [annotations])
        aligned_annotation = aligner.align_all(options).first

        if aligned_annotation.error_message
          raise "[#{annotations[:sourcedb]}:#{annotations[:sourceid]}] #{aligned_annotation.error_message}"
        end

        # Update annotation with aligned results
        annotations.merge!({
          text: ref_text,
          denotations: aligned_annotation.denotations.map(&:dup),
          blocks: aligned_annotation.blocks.map(&:dup)
        })
        annotations.delete_if { |_, v| !v.present? }

        # Check for lost annotations and add warnings
        if aligned_annotation.lost_annotations.present?
          warnings << {
            sourcedb: annotations[:sourcedb],
            sourceid: annotations[:sourceid],
            body: "Alignment failed. Invalid denotations found after transformation"
          }
        end
      rescue => e
        warnings << {
          sourcedb: annotations[:sourcedb],
          sourceid: annotations[:sourceid],
          body: "Text alignment error: #{e.message}"
        }
        return warnings
      end
    end

    # Apply project pretreatment
    project.pretreatment_according_to(options, doc, [annotations])

    # Validate for dangling references
    dangling_references = TextAlign::DanglingReferenceFinder.call(
      annotations[:denotations] || [],
      annotations[:blocks] || [],
      annotations[:relations] || [],
      annotations[:attributes] || []
    )

    if dangling_references.present?
      warnings << {
        sourcedb: annotations[:sourcedb],
        sourceid: annotations[:sourceid],
        body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join(', ')}."
      }
    else
      # Save valid annotation
      project.instantiate_and_save_annotations_collection([annotations])
    end

    warnings
  end
end
