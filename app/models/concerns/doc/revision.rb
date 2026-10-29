# frozen_string_literal: true

module Doc::Revision
  extend ActiveSupport::Concern

  def revise(new_hdoc)
    messages = []
    # As it will be stored, so it's compared, and the annotations aligned to it, with LF line endings.
    new_body = Doc.normalize_value_for(:body, new_hdoc[:text] || new_hdoc[:body])

    if new_body == self.body
      unless self.divisions == new_hdoc[:divisions]
        self.divisions.destroy_all
        self.store_divisions(new_hdoc[:divisions])
      end

      unless self.typesettings == new_hdoc[:typesettings]
        self.typesettings.destroy_all
        self.store_typesettings(new_hdoc[:typesettings])
      end
    else
      _denotations = self.denotations
      _blocks = self.blocks
      messages += AnnotationUtils.align_denotations_and_blocks!(_denotations, _blocks, self.body, new_body)

      ActiveRecord::Base.transaction do
        self.divisions.destroy_all
        self.typesettings.destroy_all
        self.body = new_body
        self.save!
        self.store_divisions(new_hdoc[:divisions])
        self.store_typesettings(new_hdoc[:typesettings])
        _denotations.each{|d| d.save!}
        _blocks.each{|b| b.save!}
      end
    end

    messages
  end

  class_methods do
    def uptodate(doc, new_hdoc = nil)
      sourcedb = doc.sourcedb
      sourceid = doc.sourceid

      new_hdoc ||= begin
        docs, messages = self.sequence_docs(sourcedb, [sourceid])
        message1 = "Could not sequence the document, #{sourcedb}:#{sourceid}"
        message1 += ": #{messages.first[:body]}" unless messages.empty?
        raise message1 unless docs.length == 1
        docs.first
      end

      ActiveRecord::Base.transaction do
        doc.revise(new_hdoc)
      end
    end
  end
end
