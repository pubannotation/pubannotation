class InstantiateAndSaveAnnotationsCollection
  class << self
    def call(project, annotations_collection)
      ActiveRecord::Base.transaction do
        # record document id
        annotations_collection.each do |ann|
          ann[:docid] = Doc.select(:id).where(sourcedb: ann[:sourcedb], sourceid: ann[:sourceid]).first.id
        end

        d_stat, d_stat_all, imported_denotations = import_denotations(project, annotations_collection)

        r_stat, r_stat_all = import_relations(project, annotations_collection, imported_denotations)
        import_attributes(project, annotations_collection, imported_denotations)
        m_stat, m_stat_all = import_modifications(project, annotations_collection, imported_denotations)

        doc_ids = Set.new annotations_collection.map { _1[:docid] }
        project_docs = project.project_docs.where(doc_id: doc_ids)

        doc_ids.each do |did|
          d_num = d_stat[did] || 0
          r_num = r_stat[did] || 0
          m_num = m_stat[did] || 0

          project_doc = project_docs.find { _1.doc_id == did }
          project_doc.increment('denotations_num', d_num)
          project_doc.increment('relations_num', r_num)
          project_doc.increment('modifications_num', m_num)
          project_doc.update_annotations_updated_at
          project_doc.doc.increment('denotations_num', d_num)
          project_doc.doc.increment('relations_num', r_num)
          project_doc.doc.increment('modifications_num', m_num)
        end

        project.increment('denotations_num', d_stat_all)
        project.increment('relations_num', r_stat_all)
        project.increment('modifications_num', m_stat_all)
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

      return [d_stat, 0, nil] unless instances.present?

      r = Denotation.import instances, validate: false
      raise "denotations import error" unless r.failed_instances.empty?
      import_denotations = instances.map.with_index { |d, index| ["#{d[:doc_id]}#{d[:project_id]}#{d[:hid]}", r.ids[index]] }
                                    .to_h

      [d_stat, instances.length, import_denotations]
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

    def import_attributes(project, annotations_collection, imported_denotations)
      instances = annotations_collection.filter { _1[:attributes].present? }
                                        .inject([]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:attributes].map do |a|
          { hid: a[:id],
            pred: a[:pred],
            subj_id: get_id_of_denotation_from(imported_denotations, project, docid, a[:subj]),
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

    def import_modifications(project, annotations_collection, imported_denotations)
      m_stat, instances = annotations_collection.filter { _1[:modifications].present? }
                                                .inject([Hash.new(0), []]) do |result, ann|
        docid = ann[:docid]
        instances = ann[:modifications].map do |a|
          { hid: a[:id],
            pred: a[:pred],
            obj_id: get_id_of_denotation_from(imported_denotations, project, docid, a[:obj]),
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
      imported_denotations["#{docid}#{project.id}#{hid}"]
    end
  end
end
