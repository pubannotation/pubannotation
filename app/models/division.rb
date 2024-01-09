class Division < ActiveRecord::Base
  belongs_to :doc

  def as_json(options = {})
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
end
