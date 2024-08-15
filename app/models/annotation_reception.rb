class AnnotationReception < ApplicationRecord
  belongs_to :annotator
  belongs_to :project
  belongs_to :job

  validates :annotator_id, presence: true
  validates :project_id, presence: true

  def process_annotation!(annotations_collection)
    annotations_collection.each do |annotations|
      raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)
    end

    symbolized_options = options.deep_symbolize_keys

    if symbolized_options[:span].present?
      messages = project.save_annotations!(annotations_collection.first, Doc.find(symbolized_options[:docid]), symbolized_options)
      messages.each do |m|
        m = {body: m} if m.class == String
        job.add_message m
      end
    else
      StoreAnnotationsCollection.new(project, annotations_collection, symbolized_options, job).call.join
    end

    job.increment!(:num_dones, annotations_collection.length)
    job.finish!
  end
end
