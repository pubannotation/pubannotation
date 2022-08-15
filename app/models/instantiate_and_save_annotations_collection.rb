class InstantiateAndSaveAnnotationsCollection
  class << self
    def call(project, annotations_collection)
      ActiveRecord::Base.transaction do
        # record document id
        annotations_collection.each do |ann|
          ann[:docid] = Doc.select(:id).where(sourcedb: ann[:sourcedb], sourceid: ann[:sourceid]).first.id
        end

        d_stat, d_stat_all = import_denotations(project, annotations_collection)
        imported_denotations = Denotation.where(project_id: project.id, doc_id: annotations_collection.map { _1[:docid] })
                                         .to_a

        r_stat, r_stat_all = import_relations(project, annotations_collection, imported_denotations)
        import_attributes(project, annotations_collection)
        m_stat, m_stat_all = import_modifications(project, annotations_collection)

        d_stat.each do |did, d_num|
          r_num = r_stat[did] ||= 0
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
      d_stat, instances = annotations_collection.filter { _1[:denotations].present? }
                                                .inject([Hash.new(0), []]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:denotations].map do |a|
          { hid: a[:id],
            begin: a[:span][:begin],
            end: a[:span][:end],
            obj: a[:obj],
            project_id: project.id,
            doc_id: docid,
            is_block: a[:block_p] }
        end

        result[0][docid] += instances.length
        result[1] += instances

        result
      end

      return [d_stat, 0] unless instances.present?

      r = Denotation.import instances, validate: false
      raise "denotations import error" unless r.failed_instances.empty?

      [d_stat, instances.length]
    end

    def import_relations(project, annotations_collection, imported_denotations)
      r_stat, instances = annotations_collection.filter { _1[:relations].present? }
                                                .inject([Hash.new(0), []]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:relations].map do |a|
          { hid: a[:id],
            pred: a[:pred],
            subj_id: get_id_of_denotation_from(imported_denotations, project, docid, a[:subj]),
            subj_type: 'Denotation',
            obj_id: get_id_of_denotation_from(imported_denotations, project, docid, a[:obj]),
            obj_type: 'Denotation',
            project_id: project.id
          }
        end

        result[0][docid] += instances.length
        result[1] += instances

        result
      end

      return [r_stat, 0] unless instances.present?

      r = Relation.import instances, validate: false
      raise "relations import error" unless r.failed_instances.empty?

      [r_stat, instances.length]
    end

    def import_attributes(project, annotations_collection)
      instances = annotations_collection.filter { _1[:attributes].present? }
                                        .inject([]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:attributes].map do |a|
          { hid: a[:id],
            pred: a[:pred],
            subj_id: Denotation.find_by!(doc_id: docid, project_id: project.id, hid: a[:subj]).id,
            subj_type: 'Denotation',
            obj: a[:obj],
            project_id: project.id
          }
        end

        result += instances

        result
      end

      return unless instances.present?

      r = Attrivute.import instances, validate: false
      raise "attribute import error" unless r.failed_instances.empty?
    end

    def import_modifications(project, annotations_collection)
      m_stat, instances = annotations_collection.filter { _1[:modifications].present? }
                                                .inject([Hash.new(0), []]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:modifications].map do |a|
          obj = Denotation.find_by!(doc_id: docid, project_id: project.id, hid: a[:obj])
          if obj.nil?
            doc = Doc.find(docid)
            doc.subcatrels.find_by_project_id_and_hid(project.id, a[:obj])
          end
          raise ArgumentError, "Invalid object of modification: #{a[:id]}" if obj.nil?

          { hid: a[:id],
            pred: a[:pred],
            obj_id: obj.id,
            obj_type: 'Denotation',
            project_id: project.id
          }
        end

        result[0][docid] += instances.length
        result[1] += instances

        result
      end

      return [m_stat, 0] unless instances.present?

      r = Modification.import instances, validate: false
      raise "modifications import error" unless r.failed_instances.empty?

      [m_stat, instances.length]
    end

    def get_id_of_denotation_from(imported_denotations, project, docid, hid)
      imported_denotations.find { _1.doc_id == docid && _1.project_id == project.id && _1.hid == hid }.id
    end
  end
end
