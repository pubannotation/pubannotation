#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'json'
require 'diff-lcs'

class Aligner

  # to work on the hash representation of catanns
  # to assume that there is no bag representation to this method
  def initialize(from_text, to_text)
    position_map = Hash.new
    numchar, numdiff, diff = 0, 0, 0

    posmap_beg = Hash.new
    posmap_end = Hash.new

    numadd, numdel = 0, 0
    Diff::LCS.sdiff(from_text, to_text) do |h|
      if h.action == '='
        if numadd + numdel > 0
          range = case numadd
          when 0
            h.new_position
          when 1
            h.new_position - 1
          else
            # h.new_position - numadd .. h.new_position - 1
            h.new_position - 1
          end

          (1 ... numdel + 1).each do |i|
            posmap_beg[h.old_position - i] = range
            posmap_end[h.old_position - i] = range
          end

          posmap_beg[h.old_position - numdel] = h.new_position - numadd
          posmap_end[h.old_position - 1] = (numadd == 0)? h.new_position : h.new_position - 1 if h.old_position > 0
          numadd, numdel = 0, 0
        end

        posmap_beg[h.old_position] = h.new_position
        posmap_end[h.old_position] = h.new_position
      else
        numadd += 1 and numdel += 1 if h.action == '!'
        numadd += 1 if h.action == '+'
        numdel += 1 if h.action == '-'
      end
    end

    last = from_text.length
    posmap_beg[last] = posmap_beg[last - 1] + 1
    posmap_end[last] = posmap_end[last - 1] + 1

    @posmap_beg, @posmap_end = posmap_beg, posmap_end
  end

  def show_alignment
    puts "[alignment for begins]-----"
    (0...@posmap_beg.size).each {|i| puts "#{i}\t#{@posmap_beg[i]}"}
    puts "[alignment for ends]-------"
    (0...@posmap_end.size).each {|i| puts "#{i}\t#{@posmap_end[i]}"}
  end

  def transform_catanns(catanns)
    return nil if catanns == nil

    catanns_new = Array.new(catanns)

    (0...catanns.length).each do |i|
      catanns_new[i][:span][:begin] = @posmap_beg[catanns[i][:span][:begin]]
      catanns_new[i][:span][:end]   = @posmap_beg[catanns[i][:span][:end]]
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

  anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  aligner = Aligner.new(anns1[:text], anns2[:text])
  catanns = aligner.transform_catanns(anns1[:catanns])

  p catanns
end
