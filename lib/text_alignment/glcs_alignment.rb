#!/usr/bin/env ruby
require 'ruby-dictionary'

module TextAlignment; end unless defined? TextAlignment

# An instance of this class holds the results of generalized LCS computation for the two strings str1 and str2.
# an optional dictionary is used for generalized suffix comparision.
class TextAlignment::GLCSAlignment
  # The mapping function from str1 to str2
  attr_reader :position_map_begin, :position_map_end

  # The position initial and final position of matching on str1 and str2
  attr_reader :str1_match_begin, :str1_match_end, :str2_match_begin, :str2_match_end

  # The length of GLCS
  attr_reader :length

  # the elements that are common in the two strings, str1 and str2
  attr_reader :common_elements

  # the elements that are mapped to each other in the two strings, str1 and str2
  attr_reader :mapped_elements

  # the string of non-mapped characters
  attr_reader :diff_strings

  attr_reader :similarity

  # It initializes the GLCS table for the given two strings, str1 and str2.
  # When the array, mappings, is given, general suffix comparision is performed based on the mappings.
  # Exception is raised when nil given passed to either str1, str2 or dictionary
  def initialize(str1, str2, mappings = [])
    raise ArgumentError, "nil string"     if str1 == nil || str2 == nil
    raise ArgumentError, "nil dictionary" if mappings == nil

    # index the mappings in hash.
    @dic = (mappings + mappings.map{|e| e.reverse}).to_h

    # prefix dictionary
    @pdic = Dictionary.new(mappings.flatten)

    @len1 = str1.length
    @len2 = str2.length

    # add a final marker to the end of the strings
    @str1 = str1 + '_'
    @str2 = str2 + '_'

    # compute the GLCS table
    @glcs = _compute_glcs_table
    @length = @glcs[0][0]

    _trace_glcs_table
  end

  # Prints the GLCS table
  def show_glcs
    puts "\t\t" + @str2.split(//).join("\t")
    @glcs.each_with_index do |row, i|
      h = (@str1[i].nil?)? '' : @str1[i]
      puts i.to_s + "\t" + h + "\t" + row.join("\t")
    end
  end

  # Returns the character-by-character difference
  def cdiff
    cdiff1, cdiff2 = '', ''
    p1, p2 = 0, 0
    begin
      s1, s2 = _prefix_eq(@str1[p1...@len1], @str2[p2...@len2])
      if s1 != nil
        l1, l2 = s1.length, s2.length

        cdiff1 += s1; cdiff2 += s2
        if l1 > l2 then cdiff2 += ' ' * (l1 - l2) else cdiff1 += ' ' * (l2 - l1) end
        p1 += s1.length;  p2 += s2.length
      elsif p2 < @len2 && (p1 == @len1 or @glcs[p1][p2 + 1] > @glcs[p1 + 1][p2])
        cdiff1 += ' '
        cdiff2 += @str2[p2]
        p2 += 1
      elsif p1 < @len1 && (p2 == @len2 or @glcs[p1][p2 + 1] <= @glcs[p1 + 1][p2])
        cdiff1 += @str1[p1]
        cdiff2 += ' '
        p1 += 1
      end
    end until p1 == @len1 && p2 == @len2

    return [cdiff1, cdiff2]
  end


  # Computes the similarity of the two strings
  def similarity(cut = false)
    c = @length

    l1 = c + @diff_strings[0].length
    l2 = c + @diff_strings[1].length

    if cut
      l1 -= front_overflow if front_overflow > 0
      l1 -= rear_overflow  if rear_overflow  > 0
      l1 += front_overflow if front_overflow < 0
      l1 += rear_overflow  if rear_overflow  < 0
    end

    similarity = 2 * c / (l1 + l2).to_f
  end

  def transform_a_span(span)
    {:begin=>@position_map_begin[span[:begin]], :end=>@position_map_end[span[:end]]}
  end

  def transform_spans(spans)
    spans.map{|span| transform_a_span(span)}
  end


  private

  # Computes the GLCS table for the two strings, @str1 and @str2.
  # Unlike normal LCS algorithms, the computation is performed from the end to the beginning of the strings.
  def _compute_glcs_table
    glcs = Array.new(@len1 + 1) { Array.new(@len2 + 1) }

    # initialize the final row and the final column
    (0..@len1).each {|p| glcs[p][@len2] = 0}
    (0..@len2).each {|p| glcs[@len1][p] = 0}

    # compute the GLCS table
    str1_reverse_iteration = (0...@len1).to_a.reverse
    str2_reverse_iteration = (0...@len2).to_a.reverse

    str1_reverse_iteration.each do |p1|
      str2_reverse_iteration.each do |p2|
        s1, s2 = _prefix_eq(@str1[p1...@len1], @str2[p2...@len2])
        unless s1 == nil
          glcs[p1][p2] = glcs[p1 + s1.length][p2 + s2.length] + 1
        else
          glcs[p1][p2] = (glcs[p1][p2 + 1] > glcs[p1 + 1][p2])? glcs[p1][p2 + 1] : glcs[p1 + 1][p2]
        end
      end
    end

    glcs
  end

  # Backtrace the GLCS table, computing the mapping function from str1 to str2
  # As its side effect, it updates four global variables
  # * front_overflow: the length of the front part of str1 that cannot fit in str2.
  # * rear_overflow: the length of the rear part of str1 that cannot fit in str2.
  # * common_elements: an array which stores the common elements in the two strings.
  # * mapped_elements: an array which stores the mapped elements in the two strings.
  def _trace_glcs_table
    @front_overflow, @rear_overflow  = 0, 0
    @common_elements, @mapped_elements = [], []
    diff_string1, diff_string2 = '', ''

    @position_map_begin, @position_map_end = {}, {}
    addition, deletion = [], []
    p1, p2 = 0, 0

    while p1 <= @len1 && p2 <= @len2
      s1, s2 = _prefix_eq(@str1[p1..@len1], @str2[p2..@len2])
      if s1 != nil
        l1, l2 = s1.length, s2.length

        @position_map_begin[p1], @position_map_end[p1] = p2, p2
        (p1 + 1 ... p1 + l1).each{|i| @position_map_begin[i], @position_map_end[i] = nil, nil}

        @common_elements << [s1, s2]

        if !addition.empty? && deletion.empty?
          # If an addition is found in the front or the rear, it is a case of underflow
          @str2_match_begin = addition.length if p1 == 0
          @str2_match_end = l2 - addition.length if p1 == @len1

          if p1 == 0
            # leave as it is
          elsif p1 == @len1
            # retract from the end
            @position_map_begin[p1] = p2 - addition.length
            @position_map_end[p1] = @position_map_begin[p1]
          else
            # correct the position for end
            @position_map_end[p1] = p2 - addition.length
          end
        elsif addition.empty? && !deletion.empty?
          # If a deletion is found in the front or the rear, it is a case of overflow
          @str1_match_begin = deletion.length if p1 == deletion.length
          @str1_match_end = l1 - deletion.length if p1 == @len1

          deletion.each{|p| @position_map_begin[p], @position_map_end[p] = p2, p2}
        elsif !addition.empty? && !deletion.empty?
          # If an addition and a deletion are both found in the front or the rear,
          # the overflow/underflow is approximated to the difference.
          al, dl = addition.length, deletion.length
          @front_overflow = dl - al if p1 == dl
          @rear_overflow  = dl - al if p1 == @len1

          @mapped_elements << [@str1[deletion[0], dl], @str2[addition[0], al]]

          @position_map_begin[deletion[0]], @position_map_end[deletion[0]] = addition[0], addition[0]
          deletion[1..-1].each{|p| @position_map_begin[p], @position_map_end[p] = nil, nil}
        end

        addition.clear; deletion.clear
        p1 += l1; p2 += l2

      elsif p2 < @len2 && (p1 == @len1 || @glcs[p1][p2 + 1] >  @glcs[p1 + 1][p2])
        diff_string2 += @str2[p2]

        addition << p2
        p2 += 1
      elsif p1 < @len1 && (p2 == @len2 || @glcs[p1][p2 + 1] <= @glcs[p1 + 1][p2])
        diff_string1 += @str1[p1]

        deletion << p1
        p1 += 1
      end
    end

    @common_elements.pop
    @diff_strings = [diff_string1, diff_string2]
  end

  # General prefix comparison is performed based on the dictionary.
  # The pair of matched suffixes are returned when found.
  # Otherwise, the pair of nil values are returned.
  def _prefix_eq(str1, str2)
    return nil, nil if str1.empty? || str2.empty?
    prefixes1 = @pdic.prefixes(str1)
    prefixes1.each {|p1| p2 = @dic[p1]; return p1, p2 if str2.start_with?(p2)}
    return str1[0], str2[0] if (str1[0] == str2[0])
    return nil, nil
  end

end

if __FILE__ == $0

  dictionary = [
                ["×", "x"],       #U+00D7 (multiplication sign)
                ["•", "*"],       #U+2022 (bullet)
                ["Δ", "delta"],   #U+0394 (greek capital letter delta)
                ["Φ", "phi"],     #U+03A6 (greek capital letter phi)
                ["α", "alpha"],   #U+03B1 (greek small letter alpha)
                ["β", "beta"],    #U+03B2 (greek small letter beta)
                ["γ", "gamma"],   #U+03B3 (greek small letter gamma)
                ["δ", "delta"],   #U+03B4 (greek small letter delta)
                ["ε", "epsilon"], #U+03B5 (greek small letter epsilon)
                ["κ", "kappa"],   #U+03BA (greek small letter kappa)
                ["λ", "lambda"],  #U+03BB (greek small letter lambda)
                ["μ", "mu"],      #U+03BC (greek small letter mu)
                ["χ", "chi"],     #U+03C7 (greek small letter chi)
                ["ϕ", "phi"],     #U+03D5 (greek phi symbol)
                [" ", " "],       #U+2009 (thin space)
                [" ", " "],       #U+200A (hair space)
                [" ", " "],       #U+00A0 (no-break space)
                ["　", " "],       #U+3000 (ideographic space)
                ["−", "-"],       #U+2212 (minus sign)
                ["–", "-"],       #U+2013 (en dash)
                ["′", "'"],       #U+2032 (prime)
                ["‘", "'"],       #U+2018 (left single quotation mark)
                ["’", "'"],       #U+2019 (right single quotation mark)
                ["“", '"'],       #U+201C (left double quotation mark)
                ["”", '"']        #U+201D (right double quotation mark)
               ]

  # str1 = "-betakappaxyz-"
  # str2 = "-ijkβκ-"

  # str1 = "-βκ-β-z-xy"
  # str2 = "abc-betakappa-beta-z"

  # str1 = "-βκ-z-xy"
  # str2 = "abc-betakappa-z"

  # str1 = "abc-βκ-β-z"
  # str2 = "-betakappa-beta-z-xyz"

  # str1 = "-β-"
  # str2 = "-beta-"

  # str1 = "-κ-"
  # str2 = "-kappa-"

  # str1 = File.read(ARGV[0]).strip
  # str2 = File.read(ARGV[1]).strip

  str1 = "beta"
  str2 = "β***"
  
  # puts "str1: #{str1}"
  # puts "str2: #{str2}"
  sa = TextAlignment::GLCSAlignment.new(str1, str2, dictionary)
  sa.position_map_begin.each {|h| p h}
  puts '-----'
  sa.position_map_end.each {|h| p h}
  puts '-----'
  puts "common_elements: #{sa.common_elements}"
  puts '-----'
  puts "mapped_elements: #{sa.mapped_elements}"
  puts '-----'
  # puts "diff_string1: #{sa.diff_strings[0]}"
  # puts "diff_string2: #{sa.diff_strings[1]}"
  puts "front_overflow: #{sa.front_overflow}"
  puts "rear_overflow : #{sa.rear_overflow}"
  puts '-----'
  puts "similarity     : #{sa.similarity}"
  puts "similarity(cut): #{sa.similarity(true)}"
end
