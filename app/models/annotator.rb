class Annotator < ActiveRecord::Base
	extend FriendlyId

	MaxTextSync  = 50000
	MaxTextAsync = 100000
	MaxWaitInQueue = 30.minutes
	MaxWaitInProcessing = 30.minutes
	MaxWaitInQueueBatch = 1.hour
	MaxWaitInProcessingBatch = 1.hour
	SkipInterval = 5

	belongs_to :user

	friendly_id :name, use: :finders
	validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
	validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

	validates :url, :presence => true
	validates :method, :presence => true
	validates :payload, :presence => true, if: :method_flagged?

	serialize :payload, coder: YAML

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
	def obtain_annotations(docs)
		method, url, params, payload = prepare_request(docs)
		result = make_request(method, url, params, payload)
		annotations_col = (result.class == Array) ? result : [result]

		# To recover the identity information, in case of syncronous annotation
		annotations_col.each_with_index do |annotations, i|
			raise RuntimeError, "Invalid annotation JSON object." unless annotations.respond_to?(:has_key?)
			annotations[:text] = docs[i][:text] unless annotations[:text].present?
			annotations[:sourcedb] = docs[i][:sourcedb] unless annotations[:sourcedb].present?
			annotations[:sourceid] = docs[i][:sourceid] unless annotations[:sourceid].present?
			AnnotationUtils.normalize!(annotations)
			annotations_transform!(annotations)
		end
		annotations_col
	end

	def annotations_transform!(annotations)
		return unless receiver_attribute.present?
		raise 'new label needs to be defined' unless new_label.present?
		new_attributes = []
		denotations_idx = {}
		a_id_num = 0
		annotations[:denotations].each do |d|
			skey = AnnotationUtils.skey_of_denotation(d, new_label)
			unless denotations_idx.has_key? skey
				new_attributes << {id:"A#{a_id_num += 1}", subj:d[:id], pred:receiver_attribute, obj:d[:obj]}
				d[:obj] = new_label
				denotations_idx[skey] = d[:id]
			else
				new_attributes << {id:"A#{a_id_num += 1}", subj:denotations_idx[skey], pred:receiver_attribute, obj:d[:obj]}
				d[:obj] = '__delme__'
			end
		end
		annotations[:denotations].delete_if{|d| d[:obj] == '__delme__'}
		annotations[:attributes] ||= []
		annotations[:attributes] += new_attributes
	end

	def single_doc_processing?
		method == 0 || url.include?('_text_') || url.include?('_sourceid_') || ['_text_', '_doc_', '_annotation_'].include?(payload['_body_'])
	end

	def prepare_request(docs)
		_method = (method == 0) ? :get : :post

		## URL check and set the default parameter
		_params = if _method == :get
			# The URL of an annotator who receives a GET request, should include the placeholder(s) of either _text_ or _sourcedb_/_sourcedb_ .
			# Otherwise, the default params will be automatically added.
			if self.url.include?('_text_') || (self.url.include?('_sourcedb_') && self.url.include?('_sourceid_'))
				nil
			else
				{'text' => '_text_'}
			end
		end

		if (docs.length > 1) && single_doc_processing?
			raise RuntimeError, "The annotation server is configured to receive only one document at a time."
		end

		## URL rewrite
		# assuming only one document is passed.
		doc = docs.first
		_url = self.url.gsub('_text_', CGI.escape(doc[:text]))
		_url.gsub!('_sourcedb_', CGI.escape(doc[:sourcedb])) if doc[:sourcedb].present?
		_url.gsub!('_sourceid_', CGI.escape(doc[:sourceid])) if doc[:sourceid].present?

		## parameter rewrite
		if _params.present?
			_params.each do |k, v|
				_params[k] = v.gsub('_text_', doc[:text]).gsub('_sourcedb_', doc[:sourcedb]).gsub('_sourceid_', doc[:sourceid])
			end
		end

		## payload rewrite
		_payload = if (_method == :post)
			# The default payload
			self.payload['_body_'] = '_doc_' unless self.payload.present?

			case self.payload['_body_']
			when '_text_'
				doc[:text]
			when '_doc_'
				doc.select{|k, v| [:text, :sourcedb, :sourceid, :divid].include? k}
			when '_annotation_'
				doc
			when '_docs_'
				docs.map{|doc| doc.select{|k, v| [:text, :sourcedb, :sourceid, :divid].include? k}}
			when '_annotations_'
				docs
			end
		end

		[_method, _url, _params, _payload]
	end

	def make_request(method, url, params = nil, payload = nil)
		payload, payload_type = if payload.class == String
			[payload, 'text/plain; charset=utf8']
		else
			[payload.to_json, 'application/json; charset=utf8']
		end

		response = if method == :post && !payload.nil?
			RestClient::Request.execute(method: method, url: url, payload: payload, max_redirects: 0, headers:{content_type: payload_type, accept: :json}, verify_ssl: false)
		else
			RestClient::Request.execute(method: method, url: url, max_redirects: 0, headers:{params: params, accept: :json}, verify_ssl: false)
		end

		raise "Unexpected response: #{response}" unless response.respond_to?(:code)
		return if self.url.include?('annotation_request')

		if response.code == 200
			result = begin
				JSON.parse response, :symbolize_names => true
			rescue => e
				raise RuntimeError, "Received an invalid JSON object: [#{response}]"
			end
		else
			raise RestClient::ExceptionWithResponse.new(response)
		end
	end

	def payload_to_string
		payload.map{|p| p.join(' = ')}.join("\n") if payload.present?
	end

	private
		def method_flagged?
			method == 1
		end
end
