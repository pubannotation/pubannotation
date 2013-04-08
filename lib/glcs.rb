#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

class GLCS

  def initialize(string1, string2, dictionary = nil)
    @dic = Hash.new()
    if dictionary
      dictionary.each do |s1, s2|
        @dic[s1] = s2
        @dic[s2] = s1
      end
    end

    @x = '-' + string1
    @y = '-' + string2

    m = @x.length
    n = @y.length

    @c = Array.new(m) { Array.new(n) }

    (0...m).each {|i| @c[i][0] = 0}
    (0...n).each {|j| @c[0][j] = 0}

    (1...m).each do |i|
      (1...n).each do |j|
        if @x[i] == @y[j]
          @c[i][j] = @c[i-1][j-1] + 1
        elsif key = suffixEq(@x[0..i], @y[0..j])
          s1, s2 = @dic.assoc(key)
          @c[i][j] = @c[i-s1.length][j-s2.length] + 1
        else
          @c[i][j] = (@c[i][j-1] > @c[i-1][j])? @c[i][j-1] : @c[i-1][j]
        end
      end
    end

    # @diff = Array.new
  end

  def suffixEq(str1, str2)
    return str1[-1] if (str1[-1] == str2[-1])
    if @dic
      @dic.each do |s1, s2|
        return s1 if str1.end_with?(s1) and str2.end_with?(s2)
      end
    end
    return nil
  end

  def printArray
    (0...@y.length).each do |j|
      print  "\t" + @y[j]
    end
    puts

    @c.each_with_index do |row, i|
      puts @x[i] + "\t" + row.join("\t")
    end
  end

  def length
    @c[@x.length - 1][@y.length - 1] 
  end

  def similarity
    m = @x.length - 1
    n = @y.length - 1
    lcs = self.length
    lcs * 2 / (m + n).to_f
  end

  def diff
    @diff = Array.new()

    i = @x.length - 1
    j = @y.length - 1

    begin
      if @x[i] == @y[j]
        @diff.unshift({:action => '=', :old_position => i-1, :old_character => @x[i], :new_position => j-1, :new_character => @y[j]})
        i -= 1; j -= 1
      elsif key = suffixEq(@x[0..i], @y[0..j])
        s1, s2 = @dic.assoc(key)
        (0...s2.length).each do |k|
          @diff.unshift({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-k-1, :new_character => @y[j-k]})
        end
        (0...s1.length).each do |k|
          @diff.unshift({:action => '-', :old_position => i-k-1, :old_character => @x[i-k], :new_position => nil, :new_character => nil})
        end
        i -= s1.length; j -= s2.length
      elsif j > 0 and (i == 0 or @c[i][j-1] >= @c[i-1][j])
        @diff.unshift({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-1, :new_character => @y[j]})
        j -= 1
      elsif i > 0 and (j == 0 or @c[i][j-1]  < @c[i-1][j])
        @diff.unshift({:action => '-', :old_position => i-1, :old_character => @x[i], :new_position => nil, :new_character => nil})
        i -= 1
      end
    end until i ==0 and j == 0

    @diff
  end

  def sdiff
    @sdiff = Array.new()

    i = @x.length - 1
    j = @y.length - 1

    begin
      if @x[i] == @y[j]
        @sdiff.unshift({:action => '=', :old_position => i-1, :old_character => @x[i], :new_position => j-1, :new_character => @y[j]})
        i -= 1; j -= 1
      elsif key = suffixEq(@x[0..i], @y[0..j])
        s1, s2 = @dic.assoc(key)
        (0...s1.length).each do |k|
          @sdiff.unshift({:action => '-', :old_position => i-k-1, :old_character => @x[i-k], :new_position => nil, :new_character => nil})
        end
        (0...s2.length).each do |k|
          @sdiff.unshift({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-k-1, :new_character => @y[j-k]})
        end
        i -= s1.length; j -= s2.length
      elsif j > 0 and (i == 0 or @c[i][j-1] > @c[i-1][j])
        @sdiff.unshift({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-1, :new_character => @y[j]})
        j -= 1
      elsif i > 0 and (j == 0 or @c[i][j-1] <= @c[i-1][j])
        # if @sdiff[0][:action] == '+'
        #   @sdiff[0][:action] = '!'
        #   @sdiff[0][:old_position] = i-1
        #   @sdiff[0][:old_character] = @x[i]
        # else
          @sdiff.unshift({:action => '-', :old_position => i-1, :old_character => @x[i], :new_position => nil, :new_character => nil})
        # end
        i -= 1
      end
    end until i ==0 and j == 0

    @sdiff
  end



  def diff_deprecate(i = nil, j = nil)
    i = @x.length - 1 unless i
    j = @y.length - 1 unless j

    if i > 0 and j > 0 and @x[i] == @y[j]
      diff(i-1, j-1)
      @diff.push({:action => '=', :old_position => i-1, :old_character => @x[i], :new_position => j-1, :new_character => @y[j]})
    elsif i > 0 and j > 0 and key = suffixEq(@x[0..i], @y[0..j])
      s1, s2 = @dic.assoc(key)
      diff(i-s1.length, j-s2.length)
      (0...s1.length).reverse_each do |k|
        @diff.push({:action => '-', :old_position => i-k-1, :old_character => @x[i-k], :new_position => nil, :new_character => nil})
      end
      (0...s2.length).reverse_each do |k|
        @diff.push({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-k-1, :new_character => @y[j-k]})
      end
    elsif j > 0 and (i == 0 or @c[i][j-1] >= @c[i-1][j])
      diff(i, j-1)
      @diff.push({:action => '+', :old_position => nil, :old_character => nil, :new_position => j-1, :new_character => @y[j]})
    elsif i > 0 and (j == 0 or @c[i][j-1]  < @c[i-1][j])
      diff(i-1, j)
      @diff.push({:action => '-', :old_position => i-1, :old_character => @x[i], :new_position => nil, :new_character => nil})
    end
  end

end

if __FILE__ == $0

  # require 'debugger'
  # debugger

  # from_text = "TGF-β mRNA"
  # to_text = "TGF-beta mRNA"

  # from_text = "TGF-a"
  # to_text = "TGF-"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF-β mRNA"

  # from_text = "TGF-beta mRNA"
  # to_text = "TGF- mRNA"

  # from_text = "TGF-β–induced"
  # to_text = "TGF-beta-induced"

  # from_text = "-βκ-"
  # to_text = "-betakappa-"

  from_text = "TGF-beta-induced"
  to_text = "TGF-β–induced"

  # from_text = "beta-induced"
  # to_text = "TGF-beta-induced"

  # from_text = "TGF-beta-induced"
  # to_text = "beta-induced"

  # from_text = "TGF-β-β induced"
  # to_text = "TGF-beta-beta induced"

  # from_text = "TGF-β–β induced"
  # to_text = "TGF-beta-beta induced"

  # anns1 = JSON.parse File.read(ARGV[0]), :symbolize_names => true
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  lcs = GLCS.new(from_text, to_text, [["Δ", "delta"], [" ", " "], ["–", "-"], ["′", "'"], ["κ", "kappa"]])
  lcs.printArray
  puts '-----'
  puts lcs.length
  puts lcs.similarity
  diff = lcs.diff
  diff.each do |d|
    p d
  end
end
