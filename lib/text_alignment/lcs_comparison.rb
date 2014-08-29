#!/usr/bin/env ruby
require 'diff-lcs'
require 'text_alignment/min_lcs_sdiff'

module TextAlignment; end unless defined? TextAlignment

class TextAlignment::LCSComparison
  # The similarity ratio of the given two strings after stripping unmatched prefixes and suffixes
  attr_reader :similarity

  # The initial and final matching positions of str1 and str2 
  attr_reader :str1_match_initial, :str1_match_final, :str2_match_initial, :str2_match_final

  def initialize(str1, str2, lcs = nil, sdiff = nil)
    raise ArgumentError, "nil string" if str1 == nil || str2 == nil
    @str1, @str2 = str1, str2
    _lcs_comparison(str1, str2, lcs, sdiff)
  end

  private

  def _lcs_comparison(str1, str2, lcs = nil, sdiff = nil)
    lcs, msdiff = TextAlignment::min_lcs_sdiff(str1, str2) if lcs.nil?

    match_initial = msdiff.index{|d| d.action == '='}
    match_final   = msdiff.rindex{|d| d.action == '='}

    @str1_match_initial = msdiff[match_initial].old_position
    @str2_match_initial = msdiff[match_initial].new_position
    @str1_match_final   = msdiff[match_final].old_position
    @str2_match_final   = msdiff[match_final].new_position
    @similarity  = 2 * lcs / ((@str1_match_final - @str1_match_initial + 1) + (@str2_match_final - @str2_match_initial + 1)).to_f
  end
end

if __FILE__ == $0
  str1 = 'naxbyzabcdexydzem'
  str2 = 'abcde'
  if ARGV.length == 2
    str1 = File.read(ARGV[0]).strip
    str2 = File.read(ARGV[1]).strip
  end
  # puts "String 1: #{str1}"
  # puts "String 2: #{str2}"
  # puts "----------"
  comparison = TextAlignment::LCSComparison.new(str1, str2)
  puts "Similarity: #{comparison.similarity}"
  puts "String 1 match: (#{comparison.str1_match_initial}, #{comparison.str1_match_final})"
  puts "String 2 match: (#{comparison.str2_match_initial}, #{comparison.str2_match_final})"
end
