#!/usr/bin/env ruby
require 'diff-lcs'

module TextAlignment; end unless defined? TextAlignment

# change the class definition of ContextChange to allow update of the two instance variables
class Diff::LCS::ContextChange
  attr_accessor :old_position, :new_position
end

# It finds minimal lcs and sdiff of the given strings, str1 and str2.
# It relies on the diff-lcs gem for the computation of lcs table.
class TextAlignment::LCSMin
  attr_reader :sdiff, :lcs, :m1_initial, :m1_final, :m2_initial, :m2_final

  PLACEHOLDER_CHAR = '_'

  def initialize (str1, str2)
    raise ArgumentError, "nil string" if str1.nil? || str2.nil?
    raise ArgumentError, "empty string" if str1.empty? || str2.empty?

    # str1 is copied as it is.
    # str2 is copied with w/s characters replaced with the placeholder characters,
    # to avoid overfitting to w/s characters during LCS computation.
    @str1 = str1
    @str2 = str2.gsub(/\s/, PLACEHOLDER_CHAR)

    # find the corresponding minimal range of the two strings
    r = _find_min_range(0, @str1.length - 1, 0, @str2.length - 1)
    @m1_initial, @m1_final, @m2_initial, @m2_final = r[:m1_initial], r[:m1_final], r[:m2_initial], r[:m2_final]

    if @m1_initial.nil?
      @sdiff = nil
      @lcs = 0
    else
      # compute sdiff and lcs
      # here the original str2 is used with all the w/s characters preserved.
      @sdiff = Diff::LCS.sdiff(@str1[@m1_initial..@m1_final], str2[@m2_initial..@m2_final])
      @lcs = @sdiff.count{|d| d.action == '='}

      # adjust the position values of sdiff
      @sdiff.each do |h|
        h.old_position += @m1_initial unless h.old_position.nil?
        h.new_position += @m2_initial unless h.new_position.nil?
      end

      (0 ... @m2_initial).reverse_each{|i| @sdiff.unshift(Diff::LCS::ContextChange.new('+', nil, nil, i, @str2[i]))}
      (0 ... @m1_initial).reverse_each{|i| @sdiff.unshift(Diff::LCS::ContextChange.new('-', i, @str1[i], nil, nil))}
      (@m1_final + 1 ... @str1.length).each{|i| @sdiff.push(Diff::LCS::ContextChange.new('-', i, @str1[i], nil, nil))}
      (@m2_final + 1 ... @str2.length).each{|i| @sdiff.push(Diff::LCS::ContextChange.new('+', nil, nil, i, @str2[i]))}
    end
  end

  def _find_min_range (m1_initial, m1_final, m2_initial, m2_final, clcs = 0)
    return nil if (m1_final - m1_initial < 0) || (m2_final - m2_initial < 0)
    sdiff = Diff::LCS.sdiff(@str1[m1_initial..m1_final], @str2[m2_initial..m2_final])
    lcs = sdiff.count{|d| d.action == '='}

    return nil if lcs == 0
    return nil if lcs < clcs

    match_last  = sdiff.rindex{|d| d.action == '='}
    m1_final    = sdiff[match_last].old_position + m1_initial
    m2_final    = sdiff[match_last].new_position + m2_initial

    match_first = sdiff.index{|d| d.action == '='}
    m1_initial  = sdiff[match_first].old_position + m1_initial
    m2_initial  = sdiff[match_first].new_position + m2_initial

    # attempt for shorter match
    if ((m1_final - m1_initial) > (m2_final - m2_initial))
      r = _find_min_range(m1_initial + 1, m1_final, m2_initial, m2_final, lcs)
      return r unless r.nil?
      r = _find_min_range(m1_initial, m1_final - 1, m2_initial, m2_final, lcs)
      return r unless r.nil?
    else
      r = _find_min_range(m1_initial, m1_final, m2_initial + 1, m2_final, lcs)
      return r unless r.nil?
      r = _find_min_range(m1_initial, m1_final, m2_initial, m2_final - 1, lcs)
      return r unless r.nil?
    end

    return {
      m1_initial: m1_initial,
      m1_final: m1_final,
      m2_initial: m2_initial,
      m2_final: m2_final
    }
  end

  def num_big_gaps (sdiff, initial, last)
    raise ArgumentError, "nil sdiff" if sdiff.nil?
    raise ArgumentError, "invalid indice: #{initial}, #{last}" unless last >= initial

    state1 = :initial
    state2 = :initial
    gaps1 = []
    gaps2 = []

    (initial .. last).each do |i|
      case sdiff[i].action
      when '='
        state1 = :continue
        state2 = :continue
      when '!'
        gaps1 << 1
        state1 = :break

        if state2 == :break
          gaps2[-1] += 1
        else
          gaps2 << 1
        end
        state2 = :continue
      when '+'
        if state1 == :break
          gaps1[-1] += 1
        else
          gaps1 << 1
        end
        state1 = :break
      when '-'
        if state2 == :break
          gaps2[-1] += 1
        else
          gaps2 << 1
        end
        state2 = :break
      end
    end

    num_big_gaps1 = gaps1.select{|g| g > MAX_LEN_BIG_GAP}.length
    num_big_gaps2 = gaps2.select{|g| g > MAX_LEN_BIG_GAP}.length
    num_big_gaps1 + num_big_gaps2
  end

end


if __FILE__ == $0
  require 'json'
  require 'text_alignment/lcs_cdiff'

  str2 = 'abcde'
  str1 = 'naxbyzabcdexydzem'

  str1 = "TI  - Identification of a region which directs the monocytic activity of the\n      colony-stimulating factor 1 (macrophage colony-stimulating factor) receptor\n      promoter and binds PEBP2/CBF (AML1)."
  str2 = "Identification of a region which directs the monocytic activity of the colony-stimulating factor 1 (macrophage colony-stimulating factor) receptor promoter and binds PEBP2/CBF (AML1).\nThe receptor for the macrophage colony-stimulating factor (or colony-stimulating factor 1 [CSF-1]) is expressed from different promoters in monocytic cells and placental trophoblasts. We have demonstrated that the monocyte-specific expression of the CSF-1 receptor is regulated at the level of transcription by a tissue-specific promoter whose activity is stimulated by the monocyte/B-cell-specific transcription factor PU.1 (D.-E. Zhang, C.J. Hetherington, H.-M. Chen, and D.G. Tenen, Mol. Cell. Biol. 14:373-381, 1994). Here we report that the tissue specificity of this promoter is also mediated by sequences in a region II (bp -88 to -59), which lies 10 bp upstream from the PU.1-binding site. When analyzed by DNase footprinting, region II was protected preferentially in monocytic cells. Electrophoretic mobility shift assays confirmed that region II interacts specifically with nuclear proteins from monocytic cells. Two gel shift complexes (Mono A and Mono B) were formed with separate sequence elements within this region. Competition and supershift experiments indicate that Mono B contains a member of the polyomavirus enhancer-binding protein 2/core-binding factor (PEBP2/CBF) family, which includes the AML1 gene product, while Mono A is a distinct complex preferentially expressed in monocytic cells. Promoter constructs with mutations in these sequence elements were no longer expressed specifically in monocytes. Furthermore, multimerized region II sequence elements enhanced the activity of a heterologous thymidine kinase promoter in monocytic cells but not other cell types tested. These results indicate that the monocyte/B-cell-specific transcription factor PU.1 and the Mono A and Mono B protein complexes act in concert to regulate monocyte-specific transcription of the CSF-1 receptor."
  # str2 = "Identification of a region which directs the monocytic activity of the colony-stimulating factor 1 (macrophage colony-stimulating factor) receptor promoter and binds PEBP2/CBF (AML1).\nThe receptor for the macrophage colony-stimulating factor (or colony-stimulating factor 1 [CSF-1]) is expressed from different promoters in monocytic cells and placental trophoblasts."

  if ARGV.length == 2
    str1 = JSON.parse(File.read(ARGV[0]).strip)["text"]
    str2 = JSON.parse(File.read(ARGV[1]).strip)["text"]
  end

  lcsmin = TextAlignment::LCSMin.new(str1, str2)
  # puts lcs
  # sdiff.each {|h| p h}
  puts TextAlignment.sdiff2cdiff(lcsmin.sdiff)
end
