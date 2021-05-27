module IniFileConvertible
  extend ActiveSupport::Concern

  # This method converts a string of a particular format to a hash,
  # such as: "key = value"
  def convert_str_to_hash(str)
    str.delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if str.present?
  end
end
