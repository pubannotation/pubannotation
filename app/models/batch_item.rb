class BatchItem
  MAX_SIZE_TRANSACTION = 5000

  attr_reader :sourcedb_sourceids_index, :annotation_transaction

  def initialize
    @annotation_transaction = []
    @sourcedb_sourceids_index = Hash.new
  end

  def <<(annotation_collection)
    @annotation_transaction << annotation_collection.annotations

    sourcedb = annotation_collection.sourcedb
    if @sourcedb_sourceids_index[sourcedb]
      @sourcedb_sourceids_index[sourcedb] << annotation_collection.sourceid
    else
      @sourcedb_sourceids_index[sourcedb] = Set.new([annotation_collection.sourceid])
    end
  end

  def enough?
    transaction_size > MAX_SIZE_TRANSACTION
  end

  private

  def transaction_size
    @annotation_transaction.map do |annotations|
      annotations.map do |annotation|
        annotation[:denotations].present? ? annotation[:denotations].size : 0
      end.sum
    end.sum
  end
end
