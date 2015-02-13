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

    # str1 is copied as it is.
    # str2 is copied with w/s characters replaced with the placeholder characters,
    # to avoid overfitting to w/s characters during LCS computation.
    @str1 = str1
    @str2 = str2.gsub(/\s/, PLACEHOLDER_CHAR)

    # find the corresponding minimal range of the two strings
    @m1_initial, @m1_final, @m2_initial, @m2_final = _find_min_range(0, @str1.length - 1, 0, @str2.length - 1)

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

  def _find_min_range (m1_initial, m1_final, m2_initial, m2_final, clcs = 0)
    return nil if (m1_final - m1_initial < 0) || (m2_final - m2_initial < 0)

    sdiff = Diff::LCS.sdiff(@str1[m1_initial..m1_final], @str2[m2_initial..m2_final])
    lcs = sdiff.count{|d| d.action == '='}

    return nil if lcs < clcs

    match_last  = sdiff.rindex{|d| d.action == '='}
    m1_final    = sdiff[match_last].old_position + m1_initial
    m2_final    = sdiff[match_last].new_position + m2_initial

    match_first = sdiff.index{|d| d.action == '='}
    m1_initial  = sdiff[match_first].old_position + m1_initial
    m2_initial  = sdiff[match_first].new_position + m2_initial

    if ((m1_final - m1_initial) > (m2_final - m2_initial))
      m1i, m1f, m2i, m2f = _find_min_range(m1_initial + 1, m1_final, m2_initial, m2_final, lcs)
      return m1i, m1f, m2i, m2f unless m1i.nil?
      m1i, m1f, m2i, m2f = _find_min_range(m1_initial, m1_final - 1, m2_initial, m2_final, lcs)
      return m1i, m1f, m2i, m2f unless m1i.nil?
    else
      m1i, m1f, m2i, m2f = _find_min_range(m1_initial, m1_final, m2_initial + 1, m2_final, lcs)
      return m1i, m1f, m2i, m2f unless m1i.nil?
      m1i, m1f, m2i, m2f = _find_min_range(m1_initial, m1_final, m2_initial, m2_final - 1, lcs)
      return m1i, m1f, m2i, m2f unless m1i.nil?
    end

    return m1_initial, m1_final, m2_initial, m2_final
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
