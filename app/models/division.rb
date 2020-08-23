class Division < ActiveRecord::Base
	belongs_to :doc

	attr_accessible :doc_id, :begin, :end, :label

	def as_json(options={})
		options ||= {}

		{
			label: self.label,
			span: {
				begin: self.begin,
				end: self.end
			}
		}
	end

end
