# frozen_string_literal: true

module Doc::TextStructure
  extend ActiveSupport::Concern

  def store_divisions(hdivisions)
    return [] if hdivisions.nil?

    divisions = hdivisions.map do |hdiv|
      Division.new(
        {
          doc_id: self.id,
          begin: hdiv[:span][:begin],
          end: hdiv[:span][:end],
          label: hdiv[:label]
        }
      )
    end

    r = Division.import divisions
    raise "Failed to save the divisions." unless r.failed_instances.empty?

    divisions
  end

  def store_typesettings(htypesettings)
    return [] if htypesettings.nil?

    typesettings = htypesettings.map do |hts|
      Typesetting.new(
        {
          doc_id: self.id,
          begin: hts[:span][:begin],
          end: hts[:span][:end],
          style: hts[:style]
        }
      )
    end

    r = Typesetting.import typesettings
    raise "Failed to save the typesettings." unless r.failed_instances.empty?

    typesettings
  end

  def get_divisions(span = nil, context_size = nil)
    if span.present?
      context_size ||= 0
      b = span[:begin] - context_size
      e = span[:end] + context_size
      b = 0 if b < 0
      e = body.length if e > body.length
      divisions.select{|t| t.begin >= b && t.end < e}.map{|t| t.begin -= b; t.end -= b; t.to_hash}
    else
      divisions.map{|t| t.to_hash}
    end
  end

  def get_typesettings(span = nil, context_size = nil)
    if span.present?
      context_size ||= 0
      b = span[:begin] - context_size
      e = span[:end] + context_size
      b = 0 if b < 0
      e = body.length if e > body.length
      typesettings.select{|t| t.begin >= b && t.end < e}.map{|t| t.begin -= b; t.end -= b; t.to_hash}
    else
      typesettings.map{|t| t.to_hash}
    end
  end

  def update_all_references_in_paragraphs = paragraphs.each { _1.update_references denotations }

  def update_all_references_in_sentences = sentences.each { _1.update_references denotations }
end
