class Sequencer < ActiveRecord::Base
  MAX_NUM_ID = 100

	extend FriendlyId
  friendly_id :name

  belongs_to :user
  attr_accessible :description, :home, :name, :parameters, :url

  validates :name, :presence => true, :length => {:minimum => 3, :maximum => 16}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

  validates :url, :presence => true

  serialize :parameters, Hash

  def get_doc(sourceid)
    response = RestClient::Request.execute(method: :get, url: url, headers:{content_type: :json, accept: :json})

    result = begin
      JSON.parse response, :symbolize_names => true
    rescue => e
      raise RuntimeError, "Received a non-JSON object: [#{response}]"
    end
    result
  end

  def get_docs(sourceids)
    ids_groups = sourceids.each_slice(MAX_NUM_ID).to_a

    result = ids_groups.inject({docs:[], messages:[]}) do |sum, ids|
      response = RestClient::Request.execute(method: :post, url: url, payload: ids.to_json, headers:{content_type: :json, accept: :json})
      result = begin
        JSON.parse response, :symbolize_names => true
      rescue => e
        {docs: [], messages: ["Received a non-JSON object: [#{response}]"]}
      end
      sum[:docs] += result[:docs] if result[:docs].present?
      sum[:messages] += result[:messages] if result[:messages].present?
      sum
    end

	  result
  end

end
