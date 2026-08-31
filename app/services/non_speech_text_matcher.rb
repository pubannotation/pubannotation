# Recognizes non-speech audio events (music, applause, etc.) that Whisper sometimes describes
# as bracketed text instead of an actual transcript, e.g. "(upbeat music)" or "[applause]" —
# a known hallucination pattern (see openai/whisper discussions #1606, #1783), inherited from
# caption conventions in its training data. There is no official/exhaustive list of the labels
# Whisper can produce this way; KNOWN_LABELS is an unverified starting guess and should be
# expanded from labels actually observed in production output, not assumed complete.
# Matched against a known label list rather than "any bracketed text", since legitimate spoken
# dialogue can itself contain parentheses (e.g. "the meeting (which ran long) covered budget").
class NonSpeechTextMatcher
  KNOWN_LABELS = [
    'music', 'upbeat music', 'suspenseful music', 'dramatic music',
    'applause', 'audience applauding', 'clapping',
    'laughter', 'laughing',
    'silence', 'background noise', 'noise', 'static'
  ].freeze

  BRACKETED_PATTERN = /\A[\(\[](.+)[\)\]]\z/

  def self.match?(text)
    return false if text.blank?

    stripped = text.strip
    return true if stripped == '♪'

    match = BRACKETED_PATTERN.match(stripped)
    return false unless match

    KNOWN_LABELS.include?(match[1].strip.downcase)
  end
end
