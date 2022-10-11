class DocumentSource
  attr_reader :db, :id

  def initialize(annotations)
    a = annotations.first

    @db = a[:sourcedb]
    @id = a[:sourceid]
  end
end
