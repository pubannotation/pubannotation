#!/usr/bin/env ruby
require 'diff-lcs'
require 'text_alignment/min_lcs_sdiff'
require 'text_alignment/lcs_comparison'

class TextAlignment::LCSAlignment
  attr_reader :position_map_begin, :position_map_end
  attr_reader :common_elements, :mapped_elements

  # It initializes the LCS table for the given two strings, str1 and str2.
  # Exception is raised when nil given passed to either str1, str2 or dictionary
  def initialize(str1, str2, lcs = nil, sdiff = nil)
    raise ArgumentError, "nil string" if str1 == nil || str2 == nil
    lcs, sdiff = TextAlignment.min_lcs_sdiff(str1, str2) if lcs.nil?
    _compute_position_map(str1, str2, sdiff)
  end

  private

  def _compute_position_map(str1, str2, sdiff)
    posmap_begin, posmap_end = {}, {}
    @common_elements, @mapped_elements = [], []

    addition, deletion = [], []

    sdiff.each do |h|
      case h.action
      when '='
        p1, p2 = h.old_position, h.new_position

        @common_elements << [str1[p1], str2[p2]]
        posmap_begin[p1], posmap_end[p1] = p2, p2

        if !addition.empty? && deletion.empty?
          # correct the position for end
          posmap_end[p1] = p2 - addition.length unless p1 == 0
        elsif addition.empty? && !deletion.empty?
          deletion.each{|p| posmap_begin[p], posmap_end[p] = p2, p2}
        elsif !addition.empty? && !deletion.empty?
          @mapped_elements << [str1[deletion[0], deletion.length], str2[addition[0], addition.length]]

          posmap_begin[deletion[0]], posmap_end[deletion[0]] = addition[0], addition[0]
          deletion[1..-1].each{|p| posmap_begin[p], posmap_end[p] = nil, nil}
        end

        addition.clear; deletion.clear

      when '!'
        deletion << h.old_position
        addition << h.new_position
      when '-'
        deletion << h.old_position
      when '+'
        addition << h.new_position
      end
    end

    p1, p2 = str1.length, str2.length
    posmap_begin[p1], posmap_end[p1] = p2, p2

    if !addition.empty? && deletion.empty?
      # correct the position for end
      posmap_end[p1] = p2 - addition.length unless p1 == 0
    elsif addition.empty? && !deletion.empty?
      deletion.each{|p| posmap_begin[p], posmap_end[p] = p2, p2}
    elsif !addition.empty? && !deletion.empty?
      @mapped_elements << [str1[deletion[0], deletion.length], str2[addition[0], addition.length]]

      posmap_begin[deletion[0]], posmap_end[deletion[0]] = addition[0], addition[0]
      deletion[1..-1].each{|p| posmap_begin[p], posmap_end[p] = nil, nil}
    end

    @position_map_begin = posmap_begin.sort.to_h
    @position_map_end = posmap_end.sort.to_h
  end

end

if __FILE__ == $0

  # from_text = "TGF-β mRNA"
  # to_text = "TGF-beta mRNA"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF-β mRNA"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF- mRNA"

  # from_text = "TGF-β–induced"
  # to_text = "TGF-beta-induced"

  from_text = 'abxyzcd'
  to_text =  'abcd'

  # from_text = "TGF-beta-induced"
  # to_text = "TGF-β–induced"

  # from_text = "beta-induced"
  # to_text = "TGF-beta-induced"

  # from_text = "TGF-beta-induced"
  # to_text = "beta-induced"

  # from_text = "TGF-β–β induced"
  # to_text = "TGF-beta-beta induced"

  # from_text = "-βκ-"
  # to_text = "-betakappa-"

  # from_text = "-betakappa-beta-z"
  # to_text = "-βκ-β–z"

  # from_text = "affect C/EBP-β’s ability"
  # to_text = "affect C/EBP-beta's ability"

  # from_text = "12 ± 34"
  # to_text = "12 +/- 34"

  # from_text = "TGF-β–treated"
  # to_text = "TGF-beta-treated"

  # from_text = "in TGF-β–treated cells"
  # to_text   = "in TGF-beta-treated cells"

  # from_text = "TGF-β–induced"
  # to_text = "TGF-beta-induced"

  # anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  # aligner = TextAlignment.new(anns1[:text], anns2[:text], [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"]])
  # denotations = aligner.transform_denotations(anns1[:denotations])

  denotations_s = <<-'ANN'
  [{"id":"T0", "span":{"begin":1,"end":2}, "category":"Protein"}]
  ANN

  # denotations = JSON.parse denotations_s, :symbolize_names => true

  a = TextAlignment::LCSAlignment.new(from_text, to_text)
  p a.position_map_begin
  puts "-----"
  p a.position_map_end
  # aligner = TextAlignment.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["β", "beta"]])

  # p denotations
end
