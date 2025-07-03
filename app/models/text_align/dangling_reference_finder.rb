# frozen_string_literal: true

module TextAlign
  module DanglingReferenceFinder
    def self.call(denotations, blocks, relations, attributes)
      db_ids = denotations.map { |d| d[:id] } + blocks.map { |b| b[:id] }
      dbr_ids = db_ids + relations.map { |d| d[:id] }

      # return dangling references
      if denotations.present? || blocks.present?
        relations.map { |r| r[:subj] }.filter { |subj| !db_ids.include? subj } +
          relations.map { |r| r[:obj] }.filter { |obj| !db_ids.include? obj } +
          attributes.map { |a| a[:subj] }.filter { |obj| !dbr_ids.include? obj }
      else
        _dangling_references = []
        if relations.present?
          _dangling_references += relations.map { |r| r[:subj] } + relations.map { |r| r[:obj] }

          r_ids = relations.map { |d| d[:id] }
          _dangling_references += attributes.map { |a| a[:subj] }.filter { |obj| !r_ids.include? obj }
        else
          _dangling_references += attributes.map { |a| a[:subj] }
        end
      end
    end
  end
end