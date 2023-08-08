class Indexer < ApplicationJob
	queue_as :elasticsearch

	def perform(org, operation, doc_id)
		doc = Doc.find(doc_id)

		case operation
			when :index
				doc.__elasticsearch__.index_document
			when :delete
				doc.__elasticsearch__.delete_document
			when :update
				doc.__elasticsearch__.update_document
			else raise ArgumentError, "Unknown operation '#{operation}'"
		end
	end
end