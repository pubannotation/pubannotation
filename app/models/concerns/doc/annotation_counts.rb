# frozen_string_literal: true

module Doc::AnnotationCounts
  extend ActiveSupport::Concern

  # returns relations count which belongs to project and doc
  def project_relations_num(project_id)
    ActiveRecord::Base.connection.select_value "SELECT relations_num FROM project_docs WHERE project_id=#{project_id} AND doc_id=#{id}"
  end

  def get_denotations_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      denotations_num
    elsif span.nil?
      ActiveRecord::Base.connection.select_value <<~SQL.squish
        SELECT denotations_num
        FROM project_docs
        WHERE project_id=#{project_id}
        AND doc_id=#{id}
      SQL
    else
      denotations.in_project_and_span(project_id, span).count
    end
  end

  def get_blocks_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      blocks_num
    elsif span.nil?
      ActiveRecord::Base.connection.select_value <<~SQL.squish
        SELECT blocks_num
        FROM project_docs
        WHERE project_id=#{project_id}
        AND doc_id=#{id}
      SQL
    else
      blocks.in_project_and_span(project_id, span).count
    end
  end

  def get_relations_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      relations_num
    elsif span.nil?
      ActiveRecord::Base.connection.select_value <<~SQL.squish
        SELECT relations_num
        FROM project_docs
        WHERE project_id=#{project_id}
        AND doc_id=#{id}
      SQL
    else
      scope = relations
        .joins("INNER JOIN denotations AS subj_d ON subj_d.id = relations.subj_id AND relations.subj_type = 'Denotation'")
        .joins("INNER JOIN denotations AS obj_d  ON obj_d.id  = relations.obj_id  AND relations.obj_type  = 'Denotation'")
        .where('subj_d.begin >= :b AND subj_d."end" <= :e', b: span[:begin], e: span[:end])
        .where('obj_d.begin  >= :b AND obj_d."end"  <= :e', b: span[:begin], e: span[:end])
      scope = scope.where(project_id: project_id) if project_id
      scope.count
    end
  end
end
