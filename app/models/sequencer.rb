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

    ids_groups.inject({docs:[], messages:[]}) do |result, ids|
      begin
        response = RestClient::Request.execute(method: :post, url: url, payload: ids.to_json, headers:{content_type: :json, accept: :json})
        begin
          r = JSON.parse response, :symbolize_names => true
          result[:docs] += r[:docs]
          result[:messages] += r[:messages]
        rescue => e
          result[:messages] << {sourcedb: name, body: "Error during JSON parsing: #{e.message}"}
        end
      rescue => e
        result[:messages] << {sourcedb: name, body: "Error during communication with the server: #{e.message}"}
      end
      result
    end
  end

  def changeable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end
end
