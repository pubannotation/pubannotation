module AnnotationCounts
  extend ActiveSupport::Concern

  def annotation_count
    self.class.annotation_count_where(id: id)
  end

  def annotation_counts
    self.class.annotation_counts_where(id: id)
  end

  class_methods do
    def annotation_count_where(conditions)
      where(conditions).pick(Arel.sql('denotations_num + blocks_num + relations_num'))
    end

    def annotation_counts_where(conditions)
      counts = where(conditions).pick(:denotations_num, :blocks_num, :relations_num)
      return if counts.nil?

      %w[denotations_num blocks_num relations_num].zip(counts).to_h
    end
  end
end
