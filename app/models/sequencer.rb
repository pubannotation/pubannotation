class Sequencer < ActiveRecord::Base
  MAX_NUM_ID = 100

  extend FriendlyId
  friendly_id :name, use: :finders

  belongs_to :user

  validates :name, :presence => true, :length => {:minimum => 3, :maximum => 16}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

  validates :url, :presence => true

  serialize :parameters, coder: JSON

  scope :accessibles, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        where("is_public = true or user_id = #{current_user.id}")
      end
    else
      where(is_public: true)
    end
  }

  def self.list(current_user = nil)
    Sequencer.accessibles(current_user).pluck(:name)
  end

  def self.accessible?(sequencer_name, current_user = nil)
    Sequencer.where(name: sequencer_name).exists?
  end

  def get_docs(sourceids)
    docs = []
    messages = []

    sourceids.each_slice(MAX_NUM_ID) do |ids|
      _docs, _messages = _get_docs(ids)
      docs += _docs
      messages += _messages
    end

    groups = messages.group_by { |message| message[:body] }
    messages = groups.map do |body, _messages|
      ids = _messages.flat_map { |message| message[:sourceid] }
      {sourcedb: name, sourceid: ids, body: body}
    end

    [docs, messages]
  end

  def _get_docs(ids)
    docs = []
    messages = []

    sleep(0.1)
    client = HTTPX.with(ssl: {verify_mode: OpenSSL::SSL::VERIFY_NONE})
    headers = {'Accept' => 'application/json'}
    response = client.post(url, body: ids.to_json, headers: headers.merge('Content-Type' => 'application/json'))
    if response.is_a?(HTTPX::Response) && response.status == 303 && response.headers['location'].present?
      redirect_url = URI.join(url, response.headers['location'])
      response = HTTPX.plugin(:follow_redirects).with(ssl: {verify_mode: OpenSSL::SSL::VERIFY_NONE}, max_redirects: 9)
                      .get(redirect_url, headers: headers)
    end
    raise HTTPX::Error, response.error.message if response.is_a?(HTTPX::ErrorResponse)
    raise HTTPX::Error, "HTTP #{response.status}" unless (200..207).cover?(response.status)

    r = JSON.parse(response.body.to_s, symbolize_names: true)
    docs = r[:docs]
    # messages = r[:messages] if r[:messages]
    [docs, []]
  rescue JSON::ParserError => e
    messages << {sourcedb: name, sourceid: ids, body: "JSON parsing error: #{e.message}"}
    [[], messages]
  rescue HTTPX::Error => e
    if ids.length > 1
      mid_index = (ids.length / 2)
      half_l = ids[0 ... mid_index]
      half_r = ids[mid_index .. -1]

      l_docs, l_messages = _get_docs(half_l)
      r_docs, r_messages = _get_docs(half_r)

      [l_docs + r_docs, l_messages + r_messages]
    else
      messages << {sourcedb: name, sourceid: ids, body: "Gateway error: #{e.message}"}
      [[], messages]
    end
  rescue => e
    messages << {sourcedb: name, sourceid: ids, body: "Unexpected error: #{e.message}"}
    [[], messages]
  end

  def changeable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end

  def parameters_to_string
    if parameters.nil? || parameters.empty?
      return 'sourceid=_sourceid_'
    else
      return parameters.map{|p| p.join(' = ')}.join("\n")
    end
  end
end
