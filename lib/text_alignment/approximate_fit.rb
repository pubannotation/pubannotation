#!/usr/bin/env ruby
module TextAlignment; end unless defined? TextAlignment

# approximate the location of str1 in str2
module TextAlignment
  SIGNATURE_NGRAM = 5
  MIN_LENGTH_FOR_APPROXIMATION = 50
  BUFFER_RATE = 0.2
end

class << TextAlignment

  # If finds an approximate region of str2 that contains str1
  def approximate_fit(str1, str2)
    raise ArgumentError, 'nil string' if str1.nil? || str2.nil?
    return 0, str2.length if str2.length < TextAlignment::MIN_LENGTH_FOR_APPROXIMATION

    ngram1 = (0 .. str1.length - TextAlignment::SIGNATURE_NGRAM).collect{|i| str1[i, TextAlignment::SIGNATURE_NGRAM]}
    ngram2 = (0 .. str2.length - TextAlignment::SIGNATURE_NGRAM).collect{|i| str2[i, TextAlignment::SIGNATURE_NGRAM]}
    ngram_shared = ngram1 & ngram2

    # If there is no shared n-gram found, it means there is no serious overlap in between the two strings
    return nil, nil if ngram_shared.empty?

    # approximate the beginning of the fit
    signature_ngram = ngram_shared.detect{|g| ngram2.count(g) == 1}
    raise "no signature ngram" if signature_ngram.nil?
    offset = str1.index(signature_ngram)
    fit_begin = str2.index(signature_ngram) - offset - (offset * TextAlignment::BUFFER_RATE).to_i
    fit_begin = 0 if fit_begin < 0    

    # approximate the end of the fit
    ngram_shared_reverse = ngram_shared.reverse
    ngram2_reverse = ngram2.reverse
    signature_ngram = ngram_shared_reverse.detect{|g| ngram2_reverse.count(g) == 1}
    raise "no signature ngram" if signature_ngram.nil?
    offset = str1.length - str1.rindex(signature_ngram)
    fit_end = str2.rindex(signature_ngram) + offset + (offset * TextAlignment::BUFFER_RATE).to_i
    fit_end = str2.length if fit_end > str2.length

    return fit_begin, fit_end
  end
end

if __FILE__ == $0
  if ARGV.length == 2
    str1 = File.read(ARGV[0]).strip
    str2 = File.read(ARGV[1]).strip

    loc = TextAlignment::approximate_fit(str1, str2)
    p loc
  end
end
