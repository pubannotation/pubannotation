class AnnotationTransaction
  MAX_SIZE_TRANSACTION = 5000

  attr_reader :sourcedb_sourceids_index, :annotation_transaction

  def initialize
    @annotation_transaction = []
    @transaction_size = 0
    @sourcedb_sourceids_index = Hash.new(Set.new)
  end

  def <<(annotation_collection)
    @annotation_transaction << annotation_collection.annotations
    @transaction_size += annotation_collection.number_of_denotations
    @sourcedb_sourceids_index[annotation_collection.sourcedb] << annotation_collection.sourceid
  end

  def enough?
    @transaction_size > MAX_SIZE_TRANSACTION
  end
end
