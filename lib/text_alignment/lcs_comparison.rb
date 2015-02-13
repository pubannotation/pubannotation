#!/usr/bin/env ruby
require 'text_alignment/lcs_min'

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
    if lcs.nil?
      lcsmin = TextAlignment::LCSMin.new(str1, str2)
      lcs = lcsmin.lcs
      sdiff = lcsmin.sdiff
    end

    if lcs > 0
      match_initial = sdiff.index{|d| d.action == '='}
      match_final   = sdiff.rindex{|d| d.action == '='}

      @str1_match_initial = sdiff[match_initial].old_position
      @str2_match_initial = sdiff[match_initial].new_position
      @str1_match_final   = sdiff[match_final].old_position
      @str2_match_final   = sdiff[match_final].new_position
      @similarity  = 2 * lcs / ((@str1_match_final - @str1_match_initial + 1) + (@str2_match_final - @str2_match_initial + 1)).to_f
    else
      @str1_match_initial = 0
      @str2_match_initial = 0
      @str1_match_final   = 0
      @str2_match_final   = 0
      @similarity         = 0
    end
  end
end

if __FILE__ == $0
  require 'json'
  str1 = 'naxbyzabcdexydzem'
  str2 = 'abcde'
  if ARGV.length == 2
    str1 = JSON.parse(File.read(ARGV[0]).strip)["text"]
    str2 = JSON.parse(File.read(ARGV[1]).strip)["text"]
  end
  comparison = TextAlignment::LCSComparison.new(str1, str2)
  puts "Similarity: #{comparison.similarity}"
  puts "String 1 match: (#{comparison.str1_match_initial}, #{comparison.str1_match_final})"
  puts "String 2 match: (#{comparison.str2_match_initial}, #{comparison.str2_match_final})"
  puts "-----"
  puts '[' + str1[comparison.str1_match_initial .. comparison.str1_match_final] + ']'
  puts "-----"
  puts '[' + str2[comparison.str2_match_initial .. comparison.str2_match_final] + ']'
end
