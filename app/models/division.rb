class Division < ActiveRecord::Base
  belongs_to :doc

  def self.store_for(doc, items)
    return [] if items.nil?

    records = items.map do |item|
      new(doc_id: doc.id, begin: item[:span][:begin], end: item[:span][:end], label: item[:label])
    end
    result = import(records)
    raise "Failed to save the divisions." unless result.failed_instances.empty?

    records
  end

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
