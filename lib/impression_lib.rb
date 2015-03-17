module ImpressionLib
  def self.popular(impressionable_type)
    Impression.
      select('DISTINCT impressionable_id, impressionable_type, COUNT(*) AS cnt, COUNT(DISTINCT ip_address) AS ip_cnt').
      includes(:impressionable).
      group(:impressionable_id, :impressionable_type).
      where('impressionable_type = ?', impressionable_type).
      order('ip_cnt DESC')
  end
end
