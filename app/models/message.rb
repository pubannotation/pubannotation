class Message < ActiveRecord::Base
	belongs_to :job
	serialize :data, coder: JSON

	def as_json(options={})
		options||={}
		json = {
			body: self.body,
			created_at: self.created_at,
		}
		json[:sourcedb] = self.sourcedb unless self.sourcedb.nil?
		json[:sourceid] = self.sourceid unless self.sourceid.nil?
		json[:divid] = self.divid unless self.divid.nil?
		json
	end

	def self.as_tsv
		column_names = %w{sourcedb sourceid divid body created_at}

		CSV.generate(col_sep: "\t") do |csv|
			csv << column_names
			all.each do |item|
				csv << item.attributes.values_at(*column_names)
			end
		end
	end
end
