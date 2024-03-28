class Sequencer < ActiveRecord::Base
	MAX_NUM_ID = 100

	extend FriendlyId
	friendly_id :name, use: :finders

	belongs_to :user

	validates :name, :presence => true, :length => {:minimum => 3, :maximum => 16}, uniqueness: true
	validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

	validates :url, :presence => true

	serialize :parameters, coder: YAML

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

	def get_doc(sourceid)
		response = RestClient::Request.execute(method: :get, url: url, headers:{content_type: :json, accept: :json}, verify_ssl: false)

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
				response = RestClient::Request.execute(method: :post, url: url, payload: ids.to_json, headers:{content_type: :json, accept: :json}, verify_ssl: false)
				begin
					r = JSON.parse response, :symbolize_names => true
					result[:docs] += r[:docs]
					result[:messages] += r[:messages] if r[:messages]
				rescue => e
					result[:messages] << {sourcedb: name, sourceid: ids.join(', '), body: "Error during JSON parsing: #{e.message}"}
				end
			rescue => e
				result[:messages] << {sourcedb: name, sourceid: ids.join(', '), body: "Error during communication with the server: #{e.message}"}
			end
			result
		end
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
