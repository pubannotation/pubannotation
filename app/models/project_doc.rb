class ProjectDoc < ActiveRecord::Base
	belongs_to :project
	belongs_to :doc

  attr_accessible :denotations_num, :relations_num, :modifications_num

  scope :simple_paginate, -> (page, per = 10) {
    page = page.nil? ? 1 : page.to_i
    offset = (page - 1) * per
    offset(offset).limit(per)
  }
end
