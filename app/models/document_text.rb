# frozen_string_literal: true

class DocumentText
  # Convert characters still present after Utfrewrite to the legacy ASCII export format.
  ASCII_REPLACEMENTS = {
    "&" => "==amp==",
    "ˆ" => "==circ==",
    "Α" => "alpha",
    "Β" => "beta",
    "Γ" => "gamma",
    "Δ" => "delta",
    "Ε" => "epsilon",
    "Ζ" => "zeta",
    "Η" => "eta",
    "Θ" => "theta",
    "Ι" => "iota",
    "Κ" => "kappa",
    "Λ" => "lambda",
    "Μ" => "mu",
    "Ν" => "nu",
    "Ξ" => "xi",
    "Ο" => "omicron",
    "Π" => "pi",
    "Ρ" => "rho",
    "Σ" => "sigma",
    "Τ" => "tau",
    "Υ" => "upsilon",
    "Φ" => "phi",
    "Χ" => "chi",
    "Ψ" => "psi",
    "Ω" => "omega",
    "α" => "alpha",
    "β" => "beta",
    "γ" => "gamma",
    "δ" => "delta",
    "ε" => "epsilon",
    "ζ" => "zeta",
    "η" => "eta",
    "θ" => "theta",
    "ι" => "iota",
    "κ" => "kappa",
    "λ" => "lambda",
    "μ" => "mu",
    "ν" => "nu",
    "ξ" => "xi",
    "ο" => "omicron",
    "π" => "pi",
    "ρ" => "rho",
    "ς" => "==sigmaf==",
    "σ" => "sigma",
    "τ" => "tau",
    "υ" => "upsilon",
    "φ" => "phi",
    "χ" => "chi",
    "ψ" => "psi",
    "ω" => "omega",
    "ϑ" => "==thetasym==",
    "ϒ" => "==upsih==",
    "ϖ" => "==piv==",
    "\u200C" => "==zwnj==",
    "\u200D" => "==zwj==",
    "\u200E" => "==lrm==",
    "\u200F" => "==rlm==",
    "†" => "==dagger==",
    "‡" => "==Dagger==",
    "…" => "...",
    "‰" => "==permil==",
    "‹" => "==lsaquo==",
    "›" => "==rsaquo==",
    "‾" => "==oline==",
    "⁄" => "==frasl==",
    "€" => "==euro==",
    "ℑ" => "==image==",
    "℘" => "==weierp==",
    "ℜ" => "==real==",
    "™" => "(TM)",
    "ℵ" => "==alefsym==",
    "←" => "==larr==",
    "↑" => "==uarr==",
    "→" => " to ",
    "↓" => "==darr==",
    "↔" => "==harr==",
    "↵" => "==crarr==",
    "⇐" => "==lArr==",
    "⇑" => "==uArr==",
    "⇒" => "==rArr==",
    "⇓" => "==dArr==",
    "⇔" => "==hArr==",
    "∀" => "==forall==",
    "∂" => "==part==",
    "∃" => "==exist==",
    "∅" => "==empty==",
    "∇" => "==nabla==",
    "∈" => "==isin==",
    "∉" => "==notin==",
    "∋" => "==ni==",
    "∏" => "==prod==",
    "∑" => "==sum==",
    "√" => "==radic==",
    "∝" => "==prop==",
    "∞" => "==infin==",
    "∠" => "==ang==",
    "∧" => "==and==",
    "∨" => "==or==",
    "∩" => "==cap==",
    "∪" => "==cup==",
    "∫" => "==int==",
    "∴" => "&there4;",
    "≅" => "==cong==",
    "≈" => "==asymp==",
    "≠" => "==ne==",
    "≡" => "==equiv==",
    "⊂" => "==sub==",
    "⊃" => "==sup==",
    "⊄" => "==nsub==",
    "⊆" => "==sube==",
    "⊇" => "==supe==",
    "⊕" => "==oplus==",
    "⊗" => "==otimes==",
    "⊥" => "==perp==",
    "⋅" => "==sdot==",
    "⌈" => "==lceil==",
    "⌉" => "==rceil==",
    "⌊" => "==lfloor==",
    "⌋" => "==rfloor==",
    "◊" => "==loz==",
    "♠" => "==spades==",
    "♣" => "==clubs==",
    "♥" => "==hearts==",
    "♦" => "==diams==",
  }.freeze
  private_constant :ASCII_REPLACEMENTS

  def initialize(body)
    @body = body
  end

  def get_slices(max_size, span = nil)
    text = get_text(span)
    length = text.length
    if length > max_size
      slices = []
      _begin = 0
      while _begin + max_size < length
        subtext = text[_begin ... _begin + max_size]
        _end = subtext.rindex("\n")
        if _end.nil?
          raise RuntimeError, "Could not split the document."
        else
          _end += _begin
        end
        slices << {begin:_begin, end:_end}
        _begin = _end + 1
      end
      slices << {begin:_begin, end:length}
      unless span.nil?
        slices.each do |slice|
          slice[:begin] += span[:begin]
          slice[:end] += span[:begin]
        end
      end
      slices
    else
      span.nil? ? [nil] : [span]
    end
  end

  def span(params)
    span = {:begin => params[:begin].to_i, :end => params[:end].to_i}
    body = self.body
    if params[:context_size].present?
      context_size = params[:context_size].to_i
      prev = {
        :begin => (span[:begin] < context_size)? 0 : span[:begin] - context_size,
        :end => span[:begin]
      }
      post = {
        :begin => span[:end],
        :end => (body.length - span[:end] < context_size)? body.length : span[:end] + context_size
      }
      prev_text = body[prev[:begin]...prev[:end]]
      post_text = body[post[:begin]...post[:end]]
    end
    return [prev_text, body[span[:begin]...span[:end]], post_text]
  end

  def text(params)
    prev_text, span, next_text = self.span(params)
    [prev_text, span, next_text].compact.join('')
  end

  def get_text(span = nil, context_size = nil)
    if span.present?
      b, e = 0, 0
      context_size ||= 0
      b = span[:begin] - context_size
      e = span[:end] + context_size
      b = 0 if b < 0
      e = body.length if e > body.length
      body[b...e]
    else
      body
    end
  end

  def to_ascii
    text = Utfrewrite.utf8_to_ascii(body).encode(Encoding::UTF_8)
    text = text.gsub(/[^\x00-\x7F]|&/) { |char| ASCII_REPLACEMENTS.fetch(char, char) }
    # The legacy export also turns literal markers in the input back into ampersands.
    text.gsub!('==amp==', '&')
    text.match?(/\A[\x01-\x7F]*\z/) ? text.encode(Encoding::US_ASCII) : text
  end

  private

  attr_reader :body
end
