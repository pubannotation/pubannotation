class Message < ActiveRecord::Base
  belongs_to :job
  attr_accessible :item, :body

  def self.as_tsv
		column_names = %w{item body created_at}

		CSV.generate(col_sep: "\t") do |csv|
			csv << column_names
			all.each do |item|
				csv << item.attributes.values_at(*column_names)
			end
		end
	end
end
