class Annotator < ActiveRecord::Base
	extend FriendlyId

  belongs_to :user
  attr_accessible :name, :description, :home, :url, :method, :payload, :batch_num, :is_public, :sample

  friendly_id :name
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

  validates :url, :presence => true
  validates :method, :presence => true
  validates :payload, :presence => true, if: 'method == 1'
  validates :batch_num, :presence => true
  validates :batch_num, :numericality => { equal_to: 0 }, if: Proc.new{|a| a.payload.present? && a.payload['_body_'] == '_text_'}

  serialize :payload, Hash

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

  def changeable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end

  # To obtain annotations from an annotator and to save them in the project
  def obtain_annotations(text)
    method, url, params, payload = prepare_request(text)
    result = make_request(method, url, params, payload)
  end

  def prepare_request(text)
    _method = (method == 0) ? :get : :post
    params = {"text" => text} if _method == :get && !url.include?('_text_')
    _url = url.gsub('_text_', URI.escape(text))

    _payload = if (_method == :post)
      if payload.present? && payload['_body_'].present?
        case payload['_body_']
        when '_text_'
          text
        when '_doc_' || '_annotation_'
          {text:text}
        end
      else
        {text:text}
      end
    end

    [_method, _url, params, _payload]
  end

  def make_request(method, url, params = nil, payload = nil)
    payload, payload_type = if payload.class == String
      [payload, 'text/plain; charset=utf8']
    else
      [payload.to_json, 'application/json; charset=utf8']
    end

    response = if method == :post && !payload.nil?
      RestClient::Request.execute(method: method, url: url, payload: payload, max_redirects: 0, headers:{content_type: payload_type, accept: :json})
    else
      RestClient::Request.execute(method: method, url: url, max_redirects: 0, headers:{params: params, accept: :json})
    end

    result = begin
      JSON.parse response, :symbolize_names => true
    rescue => e
      raise RuntimeError, "Received a non-JSON object: [#{response}]"
    end
  end

end
