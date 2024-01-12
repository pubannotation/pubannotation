# frozen_string_literal: true

class Sentence < ApplicationRecord
  self.table_name = 'blocks'
  default_scope { where obj: Pubann::Sentence::Obj }

  belongs_to :doc
end
