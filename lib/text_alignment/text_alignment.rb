#!/usr/bin/env ruby
require 'diff-lcs'
require 'text_alignment/min_lcs_sdiff'
require 'text_alignment/find_divisions'
require 'text_alignment/lcs_comparison'
require 'text_alignment/lcs_alignment'
require 'text_alignment/glcs_alignment'
require 'text_alignment/mappings'

module TextAlignment; end unless defined? TextAlignment

class TextAlignment::TextAlignment
  attr_reader :position_map_begin, :position_map_end
  attr_reader :common_elements, :mapped_elements
  attr_reader :similarity
  attr_reader :str1_match_initial, :str1_match_final, :str2_match_initial, :str2_match_final

  def initialize(str1, str2, mappings = [])
    raise ArgumentError, "nil string" if str1.nil? || str2.nil?
    raise ArgumentError, "nil mappings" if mappings.nil?

    # character mappings can be safely applied to the strings withoug changing the position of other characters
    character_mappings = mappings.select{|m| m[0].length == 1 && m[1].length == 1}
    characters_from = character_mappings.collect{|m| m[0]}.join
    characters_to   = character_mappings.collect{|m| m[1]}.join
    characters_to.gsub!(/-/, '\-')

    str1.tr!(characters_from, characters_to)
    str2.tr!(characters_from, characters_to)

    mappings.delete_if{|m| m[0].length == 1 && m[1].length == 1}

    _compute_mixed_alignment(str1, str2, mappings)
  end

  def transform_a_span(span)
    {:begin=>@position_map_begin[span[:begin]], :end=>@position_map_end[span[:end]]}
  end

  def transform_spans(spans)
    spans.map{|span| transform_a_span(span)}
  end

  def transform_denotations(denotations)
    return nil if denotations == nil
    denotations_new = Array.new(denotations)
    (0...denotations.length).each {|i| denotations_new[i][:span] = transform_a_span(denotations[i][:span])}
    denotations_new
  end

  private

  def _compute_mixed_alignment(str1, str2, mappings = [])
    lcs, sdiff = TextAlignment.min_lcs_sdiff(str1, str2)

    cmp = TextAlignment::LCSComparison.new(str1, str2, lcs, sdiff)
    @similarity         = cmp.similarity
    @str1_match_initial = cmp.str1_match_initial
    @str1_match_final   = cmp.str1_match_final
    @str2_match_initial = cmp.str2_match_initial
    @str2_match_final   = cmp.str2_match_final

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
