# frozen_string_literal: true

class Paragraph < ActiveRecord::Base
  self.table_name = 'divisions'
  default_scope { where label: 'p' }
end
