class Division < ActiveRecord::Base
  belongs_to :doc

  scope :paragpahs, -> { where(label: 'p') }

  def as_json(options = {})
    options ||= {}

    {
      label: self.label,
      span: {
        begin: self.begin,
        end: self.end
      }
    }
  end

  def to_hash
    {
      label: self.label,
      span: {
        begin: self.begin,
        end: self.end
      }
    }
  end

  def to_list_hash
    {
      sourcedb: doc.sourcedb,
      sourceid: doc.sourceid,
      begin: self.begin,
      end: self.end
    }
  end
end
