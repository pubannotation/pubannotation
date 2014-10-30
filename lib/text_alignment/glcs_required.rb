#!/usr/bin/env ruby
module TextAlignment; end unless defined? TextAlignment

class << TextAlignment
  def glcs_required?(str1, mappings = [])
    raise ArgumentError, "nil string" if str1.nil?
    raise ArgumentError, "nil mappings" if mappings.nil?

    # character mappings can be safely applied to the strings withoug changing the position of other characters
    character_mappings = mappings.select{|m| m[0].length == 1 && m[1].length == 1}
    characters_from = character_mappings.collect{|m| m[0]}.join
    characters_to   = character_mappings.collect{|m| m[1]}.join
    characters_to.gsub!(/-/, '\-')

    str1.tr!(characters_from, characters_to)

    str1 =~/([^\p{ASCII}][^\p{ASCII}])/
    $1
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

  str = "TGF-β–induced"

  # from_text = "TGF-beta-induced"
  # to_text = "TGF-β–induced"

  # from_text = "TGF-β–β induced"
  # to_text = "TGF-beta-beta induced"

  # str = "-βκ-"

  if ARGV.length == 1
    str = File.read(ARGV[0])
  end
  # anns2 = JSON.parse File.read(ARGV[1]), :symbolize_names => true

  p TextAlignment.glcs_required?(str, dictionary)
end
