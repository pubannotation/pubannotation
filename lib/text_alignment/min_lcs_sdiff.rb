#!/usr/bin/env ruby
require 'diff-lcs'

class Diff::LCS::ContextChange
  attr_accessor :old_position, :new_position
end

module TextAlignment; end unless defined? TextAlignment

class << TextAlignment

  # It finds minimal lcs and sdiff of the given strings, str1 and str2.
  # It relies on the diff-lcs gem for the computation of lcs table.
  # The resulted sdiff is a reduced one without containing the leading and trailing unmatching characters.
  def min_lcs_sdiff(str1, str2, clcs = 0)
    raise ArgumentError, "nil string" if str1 == nil || str2 == nil

    sdiff = Diff::LCS.sdiff(str1, str2)

    lcs = sdiff.count{|d| d.action == '='}
    return nil if lcs < clcs

    match_first = sdiff.index{|d| d.action == '='}
    m1_initial  = sdiff[match_first].old_position
    m2_initial  = sdiff[match_first].new_position

    match_last  = sdiff.rindex{|d| d.action == '='}
    m1_final    = sdiff[match_last].old_position
    m2_final    = sdiff[match_last].new_position

    if (m1_final - m1_initial + 1) > lcs
      rlcs, rsdiff = min_lcs_sdiff(str1[m1_initial + 1 .. m1_final], str2[m2_initial .. m2_final], lcs)
      unless rlcs.nil?
        rsdiff.each do |h|
          h.old_position += m1_initial + 1 unless h.old_position.nil?
          h.new_position += m2_initial     unless h.new_position.nil?
        end
        (0 ... m2_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        (0 ..  m1_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m1_final + 1 ... str1.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m2_final + 1 ... str2.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        return rlcs, rsdiff
      end

      rlcs, rsdiff = min_lcs_sdiff(str1[m1_initial .. m1_final - 1], str2[m2_initial .. m2_final], lcs)
      unless rlcs.nil?
        rsdiff.each do |h|
          h.old_position += m1_initial unless h.old_position.nil?
          h.new_position += m2_initial unless h.new_position.nil?
        end
        (0 ... m2_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        (0 ... m1_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m1_final ... str1.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m2_final + 1 ... str2.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        return rlcs, rsdiff
      end
    end

    if (m2_final - m2_initial + 1) > lcs
      rlcs, rsdiff = min_lcs_sdiff(str1[m1_initial .. m1_final], str2[m2_initial + 1 .. m2_final], lcs)
      unless rlcs.nil?
        rsdiff.each do |h|
          h.old_position += m1_initial     unless h.old_position.nil?
          h.new_position += m2_initial + 1 unless h.new_position.nil?
        end
        (0 ..  m2_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        (0 ... m1_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m1_final + 1 ... str1.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m2_final + 1 ... str2.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        return rlcs, rsdiff
      end

      rlcs, rsdiff = min_lcs_sdiff(str1[m1_initial .. m1_final], str2[m2_initial .. m2_final - 1], lcs)
      unless rlcs.nil?
        rsdiff.each do |h|
          h.old_position += m1_initial unless h.old_position.nil?
          h.new_position += m2_initial unless h.new_position.nil?
        end
        (0 ... m2_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        (0 ... m1_initial).reverse_each{|i| rsdiff.unshift(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m1_final + 1 ... str1.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('-', i, str1[i], nil, nil))}
        (m2_final ... str2.length).each{|i| rsdiff.push(Diff::LCS::ContextChange.new('+', nil, nil, i, str2[i]))}
        return rlcs, rsdiff
      end
    end

    return lcs, sdiff
  end
end


if __FILE__ == $0
  require 'text_alignment/lcs_cdiff'

  str2 = 'abcde'
  str1 = 'naxbyzabcdexydzem'

  if ARGV.length == 2
    str1 = File.read(ARGV[0]).strip
    str2 = File.read(ARGV[1]).strip
  end

  lcs, sdiff =TextAlignment.min_lcs_sdiff(str1, str2)
  puts lcs
  sdiff.each {|h| p h}
  puts TextAlignment.sdiff2cdiff(sdiff)
end
