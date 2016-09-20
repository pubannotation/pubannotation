class Div < ActiveRecord::Base
  belongs_to :doc, dependent: :destroy

  validates_presence_of :doc_id, :begin, :end, :section, :serial
  validates_numericality_of :doc_id, :begin, :end, :serial

  attr_accessible :begin, :end, :section, :serial

  scope :sourcedb_sourceid_serial, -> (arguments) { joins(:doc).where('docs.sourcedb = ? AND docs.sourceid = ? AND divs.serial = ?', arguments[:sourcedb], arguments[:sourceid], arguments[:serial]) }

  def body(encoding = nil)
    body = doc.body[self.begin...self.end]
    body = get_ascii_text(body)if encoding == 'ascii'
    return body
  end

  def denotations
    doc.denotations.within_span(begin: self.begin, end: self.end)
  end

  def project_denotations(project)
    denotations.where('project_id = ?', project.id)
  end

  def self.to_tsv(divs)
    headers = divs.first.to_list_hash.keys
    tsv = CSV.generate(col_sep:"\t") do |csv|
      # headers
      csv << headers
      divs.each do |div|
        div_values = Array.new
        headers.each do |key|
          div_values << div.to_list_hash[key]
        end
        csv << div_values
      end
    end
    return tsv
  end

  def to_list_hash
    {
      sourcedb: doc.sourcedb,
      sourceid: doc.sourceid,
      divid: serial,
      section:section,
      url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_index_url(doc.sourcedb, doc.sourceid)
    }
  end

  def to_hash
    {
      text: body(nil),
      sourcedb: doc.sourcedb,
      sourceid: doc.sourceid,
      divid: serial,
      section: section,
      source_url: doc.source
    }
  end

  def self.sourcedb_sourceid_serial_div(arguments)
    sourcedb_sourceid_serial(arguments).first
  end

  # TODO spec 
  def revise(div_body, current_body)
    return if div_body.chomp + '\n' == self.body

    text_aligner = TextAlignment::TextAlignment.new(self.body, div_body, TextAlignment::MAPPINGS)
    raise RuntimeError, "cannot get alignment."     if text_aligner.nil?
    raise RuntimeError, "texts too much different: #{text_aligner.similarity}." if text_aligner.similarity < 0.8

    if serial == 0
      begin_pos = 0
      end_pos = div_body.length
    else
      begin_pos = current_body.length
      end_pos = current_body.length + div_body.length
    end
    self.update_attributes(begin: begin_pos, end: end_pos)

    denotations = doc.denotations
    # need to be verified
    text_aligner.transform_denotations!(denotations)
    denotations.each{|d| d.save}
  end
end
