class Typesetting < ActiveRecord::Base
	belongs_to :doc

  def self.store_for(doc, items)
    return [] if items.nil?

    records = items.map do |item|
      new(doc_id: doc.id, begin: item[:span][:begin], end: item[:span][:end], style: item[:style])
    end
    result = import(records)
    raise "Failed to save the typesettings." unless result.failed_instances.empty?

    records
  end

	def as_json(options={})
		options ||= {}

		{
			style: self.style,
			span: {
				begin: self.begin,
				end: self.end
			}
		}
	end

	def to_hash
		{
			style: self.style,
			span: {
				begin: self.begin,
				end: self.end
			}
		}
	end
end
