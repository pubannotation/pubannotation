#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'json'
require 'diff-lcs'
require 'glcs'

class Aligner

  # to work on the hash representation of spans
  # to assume that there is no bag representation to this method
  def initialize(string1, string2, dictionary = nil)
    posmap = Hash.new

    from_text = string1.tr(" −–", " -")
    to_text   = string2.tr(" −–", " -")

    sdiff = Diff::LCS.sdiff(from_text, to_text)
    # sdiff.each_with_index do |h, i|
    #   p h
    #   break if i > 1100
    # end

    addition = []
    deletion = []

    sdiff.each do |h|
      case h.action
      when '='

        case deletion.length
        when 0
        when 1
          posmap[deletion[0]] = addition[0]
        else
          gdiff = GLCS.new(from_text[deletion[0]..deletion[-1]], to_text[addition[0]..addition[-1]], dictionary).sdiff

          # gdiff.each do |gg|
          #   p gg
          # end
          # puts "-------------"

          new_position = 0
          state = '='
          gdiff.each_with_index do |g, i|
            if g[:action] ==  '+'
              new_position = g[:new_position] unless state == '+'
              state = '+'
            end

            if g[:action] == '-'
              posmap[g[:old_position] + deletion[0]] = new_position + addition[0]
              state = '-'
            end
          end
        end

        addition.clear
        deletion.clear

        posmap[h.old_position] = h.new_position
      when '!'
        deletion << h.old_position
        addition << h.new_position
      when '-'
        deletion << h.old_position
      when '+'
        addition << h.new_position
      end
    end

    last = from_text.length
    posmap[last] = posmap[last - 1] + 1

    @posmap = posmap
  end

  def show_alignment
    (0...@posmap.size).each {|i| puts "#{i}\t#{@posmap[i]}"}
  end

  def transform_spans(spans)
    return nil if spans == nil

    spans_new = Array.new(spans)

    (0...spans.length).each do |i|
      spans_new[i][:span][:begin] = @posmap[spans[i][:span][:begin]]
      spans_new[i][:span][:end]   = @posmap[spans[i][:span][:end]]
    end

    spans_new
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

  from_text = "12 ± 34"
  to_text = "12 +/- 34"

  from_text = "TGF-β–treated"
  to_text = "TGF-beta-treated"

  from_text = "in TGF-β–treated cells"
  to_text   = "in TGF-beta-treated cells"

  # from_text = "TGF-β–induced"
  # to_text = "TGF-beta-induced"

  # anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  # aligner = Aligner.new(anns1[:text], anns2[:text], [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"]])
  # spans = aligner.transform_spans(anns1[:spans])

  spans_s = <<-'ANN'
  [{"id":"T0","span":{"begin":1,"end":2},"category":"Protein"}]
  ANN

  spans = JSON.parse spans_s, :symbolize_names => true

  aligner = Aligner.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["’", "'"]])
  # aligner = Aligner.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["β", "beta"]])
  aligner.show_alignment
  spans = aligner.transform_spans(spans)

  p spans
end
