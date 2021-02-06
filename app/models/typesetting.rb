class Typesetting < ActiveRecord::Base
	belongs_to :doc

	attr_accessible :doc_id, :begin, :end, :style

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
