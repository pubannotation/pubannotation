class ProjectDoc < ActiveRecord::Base
	belongs_to :project
	belongs_to :doc

  attr_accessible :denotations_num, :relations_num, :modifications_num

  scope :simple_paginate, -> (page, per = 10) {
    page = page.nil? ? 1 : page.to_i
    offset = (page - 1) * per
    offset(offset).limit(per)
  }

  def graph_uri
    doc_spec = doc.has_divs? ?
      "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/divs/{doc.serial}" :
      "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"
    project.graph_uri + doc_spec
  end
end
