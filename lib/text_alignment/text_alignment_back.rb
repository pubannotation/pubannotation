#!/usr/bin/env ruby
require 'diff-lcs'
require 'text_alignment/glcs_alignment'

# to work on the hash representation of denotations
# to assume that there is no bag representation to this method
module TextAlignment; end unless defined? TextAlignment

class << TextAlignment
  def find_divisions(target, sources, mappings = [])
    raise ArgumentError, "nil target"           if target == nil
    raise ArgumentError, "nil or empty sources" if sources == nil || sources.empty?
    raise ArgumentError, "nil mappings"         if mappings == nil

    character_mappings = mappings.select{|m| m[0].length == 1 && m[1].length == 1}
    mappings.delete_if{|m| m[0].length == 1 && m[1].length == 1}
    characters_from = character_mappings.collect{|m| m[0]}.join
    characters_to   = character_mappings.collect{|m| m[1]}.join
    characters_to.gsub!(/-/, '\-')

    target.tr!(characters_from, characters_to)
    sources.each{|source| source.tr!(characters_from, characters_to)}

    self._find_divisions(target, sources)
  end

  def find_divisions(target, sources)
    m, sa = nil, nil
    (0..sources.size).each do |i|
      mode, str1, str2 = (target.size < sources[i]) ? :t_in_s, target.size, sources[i] : :s_in_t, sources[i], target
      if (str2 - str1) / str1.to_f > 

      sa = self._sequence_comparisoneSequenceAlignment.new(source, targets[i])
      if sa.front_overflow < PTHRESHOLD && sa.similarity(true) > STHRESHOLD
        m = i
        break
      end
    end

    raise "cannot find" if m.nil?

    index = [i, [sa.front_overflow, targets.size - sa.rear_overflow]]
    logger.debug "matched to div-#{i}' <-----"

    targets.delete_at(i)
    if targets.empty?
      return index
    else
      return index + distribute_annotations(source[-sa.rear_overflow..-1], targets)
    end
  end

end

  # def temp
  #   posmap = Hash.new

  #   # adhoc: need to be improved
  #   from_text = string1.tr(" −–", " -")
  #   to_text   = string2.tr(" −–", " -")

  #   sdiff = Diff::LCS.sdiff(from_text, to_text)

  #   puts
  #   sdiff.each_with_index do |h, i|
  #     # p h
  #     break if i > 1100
  #   end

  #   addition = []
  #   deletion = []

  #   sdiff.each do |h|
  #     case h.action
  #     when '='

  #       case deletion.length
  #       when 0
  #       when 1
  #         posmap[deletion[0]] = addition[0]
  #       else
  #         gdiff = GLCS.new(from_text[deletion[0]..deletion[-1]], to_text[addition[0]..addition[-1]], dictionary).sdiff

  #         # gdiff.each do |gg|
  #         #   p gg
  #         # end
  #         # puts "-------------"

  #         new_position = 0
  #         state = '='
  #         gdiff.each_with_index do |g, i|
  #           if g[:action] ==  '+'
  #             new_position = g[:new_position] unless state == '+'
  #             state = '+'
  #           end

  #           if g[:action] == '-'
  #             posmap[g[:old_position] + deletion[0]] = new_position + addition[0]
  #             state = '-'
  #           end
  #         end
  #       end

  #       addition.clear
  #       deletion.clear

  #       posmap[h.old_position] = h.new_position
  #     when '!'
  #       deletion << h.old_position
  #       addition << h.new_position
  #     when '-'
  #       deletion << h.old_position
  #     when '+'
  #       addition << h.new_position
  #     end
  #   end

  #   last = from_text.length
  #   # p posmap
  #   # p last
  #   posmap[last] = posmap[last - 1] + 1

  #   # p posmap
  #   # puts '-=-=-=-=-=-=-'

  #   @posmap = posmap
  # end

  # def mapping
  #   @posmap
  # end

  # def show_mapping
  #   (0...@posmap.size).each {|i| puts "#{i}\t#{@posmap[i]}"}
  # end

  # def transform_denotations(denotations)
  #   return nil if denotations == nil

  #   denotations_new = Array.new(denotations)

  #   (0...denotations.length).each do |i|
  #     denotations_new[i][:span][:begin] = @posmap[denotations[i][:span][:begin]]
  #     denotations_new[i][:span][:end]   = @posmap[denotations[i][:span][:end]]
  #   end

  #   denotations_new
  # end



if __FILE__ == $0

  # from_text = "TGF-β mRNA"
  # to_text = "TGF-beta mRNA"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF-β mRNA"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF- mRNA"

  from_text = "TGF-β–induced"
  to_text = "TGF-beta-induced"

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

  TextAlignment.find_divisions(from_text, [to_text], [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["’", "'"]])
  # aligner = TextAlignment.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["β", "beta"]])

  # p denotations
end
