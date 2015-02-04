#!/usr/bin/env ruby
require 'diff-lcs'
require 'text_alignment/lcs_min'
require 'text_alignment/find_divisions'
require 'text_alignment/lcs_comparison'
require 'text_alignment/lcs_alignment'
require 'text_alignment/glcs_alignment'
require 'text_alignment/mappings'

module TextAlignment; end unless defined? TextAlignment

TextAlignment::SIGNATURE_NGRAM = 5 unless defined? TextAlignment::SIGNATURE_NGRAM

class TextAlignment::GLCSTextAlignment
  attr_reader :position_map_begin, :position_map_end
  attr_reader :common_elements, :mapped_elements
  attr_reader :similarity
  attr_reader :str1_match_initial, :str1_match_final, :str2_match_initial, :str2_match_final

  def initialize(str1, str2, mappings = [], lcs = nil, sdiff = nil)
    raise ArgumentError, "nil string" if str1.nil? || str2.nil?
    raise ArgumentError, "nil mappings" if mappings.nil?

    _glcs_alignment_fast(str1, str2, mapptings, lcs, sdiff)
  end

  private

  def _glcs_alignment_fast(str1, str2, mappings, lcs, sdiff)
    sdiff = TextAlignment::LCSMin.new(str1, str2).sdiff if sdiff.nil?

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
          posmap_end[p1] = p2 - addition.length unless p1 == 0
        elsif addition.empty? && !deletion.empty?
          deletion.each{|p| posmap_begin[p], posmap_end[p] = p2, p2}
        elsif !addition.empty? && !deletion.empty?
          if addition.length > 1 || deletion.length > 1
            galign = TextAlignment::GLCSAlignment.new(str1[deletion[0] .. deletion[-1]], str2[addition[0] .. addition[-1]], mappings)
            galign.position_map_begin.each {|k, v| posmap_begin[k + deletion[0]] = v.nil? ? nil : v + addition[0]}
            galign.position_map_end.each   {|k, v|   posmap_end[k + deletion[0]] = v.nil? ? nil : v + addition[0]}
            posmap_begin[p1], posmap_end[p1] = p2, p2
            @common_elements += galign.common_elements
            @mapped_elements += galign.mapped_elements
          else
            posmap_begin[deletion[0]], posmap_end[deletion[0]] = addition[0], addition[0]
            deletion[1..-1].each{|p| posmap_begin[p], posmap_end[p] = nil, nil}
            @mapped_elements << [str1[deletion[0], deletion.length], str2[addition[0], addition.length]]
          end
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
      posmap_end[p1] = p2 - addition.length unless p1 == 0
    elsif addition.empty? && !deletion.empty?
      deletion.each{|p| posmap_begin[p], posmap_end[p] = p2, p2}
    elsif !addition.empty? && !deletion.empty?
      if addition.length > 1 && deletion.length > 1
        galign = TextAlignment::GLCSAlignment.new(str1[deletion[0] .. deletion[-1]], str2[addition[0] .. addition[-1]], mappings)
        galign.position_map_begin.each {|k, v| posmap_begin[k + deletion[0]] = v.nil? ? nil : v + addition[0]}
        galign.position_map_end.each   {|k, v|   posmap_end[k + deletion[0]] = v.nil? ? nil : v + addition[0]}
        posmap_begin[p1], posmap_end[p1] = p2, p2
        @mapped_elements += galign.common_elements + galign.mapped_elements
      else
        posmap_begin[deletion[0]], posmap_end[deletion[0]] = addition[0], addition[0]
        deletion[1..-1].each{|p| posmap_begin[p], posmap_end[p] = nil, nil}
        @mapped_elements << [str1[deletion[0], deletion.length], str2[addition[0], addition.length]]
      end
    end

    @position_map_begin = posmap_begin.sort.to_h
    @position_map_end = posmap_end.sort.to_h
  end
end

if __FILE__ == $0
  str1 = '-βκ-'
  str2 = '-betakappa-'

  # anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  dictionary = [["β", "beta"]]
  # align = TextAlignment::TextAlignment.new(str1, str2)
  align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)
  p align.common_elements
  p align.mapped_elements
end
