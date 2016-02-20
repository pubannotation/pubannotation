#!/usr/bin/env ruby
require 'diff-lcs'

module TextAlignment; end unless defined? TextAlignment

module TextAlignment
  NIL_CHARACTER = '_'
end

class << TextAlignment

  def cdiff(str1, str2)
    raise ArgumentError, "nil string" if str1.nil? || str2.nil?
    raise "a nil character appears in the input string" if str1.index(TextAlignment::NIL_CHARACTER) || str2.index(TextAlignment::NIL_CHARACTER)
    sdiff2cdiff(Diff::LCS.sdiff(str1, str2))
  end

  def sdiff2cdiff (sdiff)
    raise ArgumentError, "nil sdiff" if sdiff.nil?

    cdiff_str1, cdiff_str2 = '', ''

    sdiff.each do |h|
      case h.action
      when '='
        cdiff_str1 += h.old_element
        cdiff_str2 += h.new_element
      when '!'
        cdiff_str1 += h.old_element + TextAlignment::NIL_CHARACTER
        cdiff_str2 += TextAlignment::NIL_CHARACTER + h.new_element
      when '-'
        cdiff_str1 += h.old_element
        cdiff_str2 += TextAlignment::NIL_CHARACTER
      when '+'
        cdiff_str1 += TextAlignment::NIL_CHARACTER
        cdiff_str2 += h.new_element
      end
    end

    cdiff_str1.gsub(/\n/, ' ') + "\n" + cdiff_str2.gsub(/\n/, ' ')
  end

end

if __FILE__ == $0
  require 'json'
  str1 = 'abcde'
  str2 = 'naxbyzabcdexydzem'

  if ARGV.length == 2
    str1 = JSON.parse(File.read(ARGV[0]).strip)["text"]
    str2 = JSON.parse(File.read(ARGV[1]).strip)["text"]
  end

  puts "string 1: #{str1}"
  puts "-----"
  puts "string 2: #{str2}"
  puts "-----"
  puts "[cdiff]"
  puts TextAlignment::cdiff(str1, str2)
end
