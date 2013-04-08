#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'json'
require 'diff-lcs'
require 'glcs'

class Aligner

  # to work on the hash representation of catanns
  # to assume that there is no bag representation to this method
  def initialize(from_text, to_text, dictionary = nil)
    posmap = Hash.new

    sdiff = Diff::LCS.sdiff(from_text, to_text)

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

  def transform_catanns(catanns)
    return nil if catanns == nil

    catanns_new = Array.new(catanns)

    (0...catanns.length).each do |i|
      catanns_new[i][:span][:begin] = @posmap[catanns[i][:span][:begin]]
      catanns_new[i][:span][:end]   = @posmap[catanns[i][:span][:end]]
    end

    catanns_new
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

  from_text = "-betakappa-beta-z"
  to_text = "-βκ-β–z"

  # from_text = "TGF-β–induced"
  # to_text = "TGF-beta-induced"

  # anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  # aligner = Aligner.new(anns1[:text], anns2[:text], [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"]])
  # catanns = aligner.transform_catanns(anns1[:catanns])

  catanns_s = <<-'ANN'
  [{"id":"T0","span":{"begin":1,"end":2},"category":"Protein"}]
  ANN

  catanns = JSON.parse catanns_s, :symbolize_names => true

  aligner = Aligner.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["κ", "kappa"]])
  # aligner = Aligner.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["β", "beta"]])
  aligner.show_alignment
  catanns = aligner.transform_catanns(catanns)

  p catanns
end
