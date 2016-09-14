class Div < ActiveRecord::Base
  belongs_to :doc, dependent: :destroy

  attr_accessible :begin, :end, :section, :serial
end
