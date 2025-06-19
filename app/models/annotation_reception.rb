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

      if symbolized_options[:span].present?
        messages = project.save_annotations!(annotations, Doc.find(hdoc_info[:docid]), symbolized_options)
        messages.each do |m|
          m = { body: m } if m.is_a?(String)
          job.add_message(m)
        end
      else
        StoreAnnotationsCollection::Main.new(project, [annotations], symbolized_options, job).call.join
      end
    end

    job.increment!(:num_dones)
    job.finish!
  end
end
