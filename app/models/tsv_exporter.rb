# frozen_string_literal: true

class TsvExporter
  def self.call(rows)
    return nil if rows.blank?

    CSV.generate(col_sep: "\t") do |csv|
      csv << rows.first.keys
      rows.each { |row| csv << row.values }
    end
  end
end
