# frozen_string_literal: true

module Doc::Serialization
  extend ActiveSupport::Concern

  def hdoc
    {
      text: body,
      sourcedb: sourcedb,
      sourceid: sourceid
    }
  end

  def to_hash(span = nil, context_size = nil)
    {
      target: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, only_path: false),
      sourcedb: sourcedb,
      sourceid: sourceid,
      source_url: source,
      text: get_text(span, context_size),
      divisions: get_divisions(span, context_size),
      typesettings: get_typesettings(span, context_size)
    }.reject{|k, v| k != :text && (v.nil? || v.empty?)}
  end

  def to_list_hash
    {
      sourcedb: sourcedb,
      sourceid: sourceid,
      url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(self.sourcedb, self.sourceid)
    }
  end

  class_methods do
    def hash_to_tsv(docs)
      return nil unless docs.present?
      headers = docs.first.keys
      tsv = CSV.generate(col_sep:"\t") do |csv|
        # headers
        csv << headers
        docs.each do |doc|
          csv << doc.values
        end
      end
      return tsv
    end

    def to_tsv(docs, doc_type)
      headers = docs.first.to_list_hash().keys
      tsv = CSV.generate(col_sep:"\t") do |csv|
        # headers
        csv << headers
        docs.each do |doc|
          doc_values = Array.new
          headers.each do |key|
            doc_values << doc.to_list_hash()[key]
          end
          csv << doc_values
        end
      end
      return tsv
    end
  end
end
