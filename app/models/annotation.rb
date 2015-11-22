require 'zip/zip'
include AnnotationsHelper

class Annotation < ActiveRecord::Base

  def self.get_files_from_zip(zip_file_path)
    files = Zip::ZipFile.open(zip_file_path) do |zip|
      zip.collect do |entry|
        next if entry.ftype == :directory
        next unless entry.name.end_with?('.json')
        {name:entry.name, content:entry.get_input_stream.read}
      end.delete_if{|e| e.nil?}
    end
    raise IOError, "No JSON file found" unless files.length > 0
    files
  end

  def self.get_annotations_collection(files)
    error_files = []
    annotations_collection = files.inject([]) do |m, file|
      begin
        as = JSON.parse(file[:content], symbolize_names:true)
        if as.is_a?(Array)
          m + as
        else
          m + [as]
        end
      rescue => e
        error_files << file[:name]
        m
      end
    end
    raise IOError, "Invalid JSON files: #{error_files.join(', ')}" unless error_files.empty?

    error_anns = []
    annotations_collection.each do |annotations|
      if annotations[:text].present? && annotations[:sourcedb].present? && annotations[:sourceid].present?
      else
        error_anns << if annotations[:sourcedb].present? && annotations[:sourceid].present?
          "#{annotations[:sourcedb]}:#{annotations[:sourceid]}"
        elsif annotations[:text].present?
          annotations[:text][0..10] + "..."
        else
          '???'
        end
      end
    end
    raise IOError, "Invalid annotation found. An annotation has to include at least the four components, text, denotation, sourcedb, and sourceid: #{error_anns.join(', ')}" unless error_anns.empty?

    error_anns = []
    annotations_collection.each do |annotations|
      begin
        normalize_annotations!(annotations)
      rescue => e
        error_anns << "#{annotations[:sourcedb]}:#{annotations[:sourceid]}"
      end
    end
    raise IOError, "Invalid annotations: #{error_anns.join(', ')}" unless error_anns.empty?

    annotations_collection
  end

end