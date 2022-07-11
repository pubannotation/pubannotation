class InstantiateAndSaveAnnotationsCollection
  class << self
    def call(project, annotations_collection)
      ActiveRecord::Base.transaction do
        # record document id
        annotations_collection.each do |ann|
          ann[:docid] = Doc.select(:id).where(sourcedb: ann[:sourcedb], sourceid: ann[:sourceid]).first.id
        end

        d_stat, d_stat_all = import_denotations(project, annotations_collection)
        r_stat, r_stat_all = import_relations(project, annotations_collection)
        a_stat = import_attributes(project, annotations_collection)
        m_stat, m_stat_all = import_modifications(project, annotations_collection)

        d_stat.each do |did, d_num|
          r_num = r_stat[did] ||= 0
          a_num = a_stat[did] ||= 0
          m_num = m_stat[did] ||= 0
          ActiveRecord::Base.connection.exec_query("UPDATE project_docs SET denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} WHERE project_id=#{project.id} AND doc_id=#{did}")
          ActiveRecord::Base.connection.execute("UPDATE docs SET denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} WHERE id=#{did}")
        end

        annotations_collection.each do |ann|
          ActiveRecord::Base.connection.exec_query("UPDATE project_docs SET annotations_updated_at = CURRENT_TIMESTAMP WHERE project_id=#{project.id} AND doc_id=#{ann[:docid]}")
        end

        ActiveRecord::Base.connection.execute("UPDATE projects SET denotations_num = denotations_num + #{d_stat_all}, relations_num = relations_num + #{r_stat_all}, modifications_num = modifications_num + #{m_stat_all} WHERE id=#{project.id}")

        project.update_annotations_updated_at
        project.update_updated_at
      end
    end

    private

    def import_denotations(project, annotations_collection)
      d_stat = Hash.new(0)
      instances = []

      annotations_collection.each do |ann|
        next unless ann[:denotations].present?
        docid = ann[:docid]
        instances += project.instantiate_hdenotations(ann[:denotations], docid)
        d_stat[docid] += ann[:denotations].length
      end

      if instances.present?
        r = Denotation.import instances, validate: false
        raise "denotations import error" unless r.failed_instances.empty?
      end

      d_stat_all = instances.length

      [d_stat, d_stat_all]
    end

    def import_relations(project, annotations_collection)
      r_stat = Hash.new(0)
      instances = []

      annotations_collection.each do |ann|
        next unless ann[:relations].present?
        docid = ann[:docid]
        instances += project.instantiate_hrelations(ann[:relations], docid)
        r_stat[docid] += ann[:relations].length
      end

      if instances.present?
        r = Relation.import instances, validate: false
        raise "relations import error" unless r.failed_instances.empty?
      end

      r_stat_all = instances.length

      [r_stat, r_stat_all]
    end

    def import_attributes(project, annotations_collection)
      a_stat = Hash.new(0)
      instances = []

      annotations_collection.each do |ann|
        next unless ann[:attributes].present?
        docid = ann[:docid]
        instances += project.instantiate_hattributes(ann[:attributes], docid)
      end

      if instances.present?
        r = Attrivute.import instances, validate: false
        raise "attribute import error" unless r.failed_instances.empty?
      end

      a_stat
    end

    def import_modifications(project, annotations_collection)
      m_stat = Hash.new(0)
      instances = []

      annotations_collection.each do |ann|
        next unless ann[:modifications].present?
        docid = ann[:docid]
        instances += project.instantiate_hmodifications(ann[:modifications], docid)
        m_stat[docid] += ann[:modifications].length
      end

      if instances.present?
        r = Modification.import instances, validate: false
        raise "modifications import error" unless r.failed_instances.empty?
      end

      m_stat_all = instances.length

      [m_stat, m_stat_all]
    end
  end
end
