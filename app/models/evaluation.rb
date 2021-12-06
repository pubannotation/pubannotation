class Evaluation < ActiveRecord::Base
	belongs_to :study_project, class_name: 'Project'
	belongs_to :reference_project, class_name: 'Project'
	belongs_to :evaluator

	validates :user_id, presence: true
	validates :study_project, presence: true
	validates :reference_project, presence: true
	validates :evaluator, presence: true
	validates_each :reference_project do |record, attr, value|
		unless value.nil?
			if value == record.study_project
				record.errors.add(attr, "must be a different one from the study_project.")
			else
				docs_std = record.study_project.docs
				docs_ref = value.docs
				docs_common = docs_std & docs_ref
				record.errors.add(attr, "has no shared document with the study project.") if docs_common.length == 0
				record.errors.add(attr, "has too many (> 5,000) shared document with the study project.") if docs_common.length > 5000
			end
		end
	end

	scope :accessible, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where('evaluations.is_public = ? OR evaluations.user_id = ?', true, current_user.id)
			end
		else
			where('evaluations.is_public = true')
		end
	}

	def changeable?(current_user)
		current_user.present? && (current_user.root? || current_user == study_project.user)
	end

	def obtain
		raise RuntimeError, "The method is valid only when the evaluator is a web service."unless evaluator.access_type == 2
		raise RuntimeError, "The URL of the evaluation web service is not specified." unless evaluator.url.present?

		annotations_col = study_project.docs.collect{|doc| doc.hannotations(study_project)}
		result = make_request(evaluator.url, annotations_col)
		update_attribute(:result, JSON.generate(result))

		result
	end

	def make_request(url, annotations_col)
		response = begin
			RestClient::Request.execute(method: :post, url: url, payload: annotations_col.to_json, max_redirects: 0, headers:{content_type: 'application/json; charset=utf8', accept: :json}, verify_ssl: false)
		rescue => e
			raise "The evaluation service reported a problem: #{e.message}"
		end

		result = begin
			JSON.parse response, :symbolize_names => true
		rescue => e
			raise RuntimeError, "Received a non-JSON object: [#{response}]"
		end
	end
end
