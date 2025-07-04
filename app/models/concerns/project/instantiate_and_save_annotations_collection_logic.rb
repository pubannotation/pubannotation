# frozen_string_literal: true
#
module Project::InstantiateAndSaveAnnotationsCollectionLogic
  extend ActiveSupport::Concern

  def pretreatment_according_to(options, document, annotations)
    if options[:mode] == 'replace'
      self.delete_doc_annotations document
    else
      case options[:mode]
      when 'add'
        annotations.each { |a| self.reid_annotations!(a, document) }
      when 'merge'
        annotations.each { |a| self.reid_annotations!(a, document) }
        base_annotations = document.hannotations(self, nil, nil)
        annotations.each { |a| AnnotationUtils.prepare_annotations_for_merging!(a, base_annotations) }
      end
    end
  end

  def instantiate_and_save_annotations_collection(annotations_collection)
    ActiveRecord::Base.transaction do
      record_docid(annotations_collection)

      d_stat, d_stat_all, imported_denotations = import_denotations(self, annotations_collection)
      b_stat, b_stat_all, imported_blocks = import_blocks(self, annotations_collection)
      r_stat, r_stat_all, imported_relations = import_relations(self, annotations_collection, imported_denotations, imported_blocks)

      import_attributes(self, annotations_collection, imported_denotations, imported_blocks, imported_relations)

      doc_ids = Set.new annotations_collection.map { _1[:docid] }

      if doc_ids.present?
        project_docs = self.project_docs.where(doc_id: doc_ids)

        doc_ids.each do |did|
          d_num = d_stat[did] || 0
          b_num = b_stat[did] || 0
          r_num = r_stat[did] || 0

          project_doc = project_docs.find { _1.doc_id == did }
          update_project_doc(project_doc, d_num, b_num, r_num)
        end
      end

      update_project(self, d_stat_all, b_stat_all, r_stat_all)
    end
  end

  private

  def record_docid(annotations_collection)
    annotations_collection.each do |ann|
      ann[:docid] = Doc.where(sourcedb: ann[:sourcedb], sourceid: ann[:sourceid]).pluck(:id).first
    end
  end

  def update_project_doc(project_doc,  d_num, b_num, r_num)
    raise unless project_doc

    project_doc.increment('denotations_num', d_num)
    project_doc.increment('blocks_num', b_num)
    project_doc.increment('relations_num', r_num)
    project_doc.update_annotations_updated_at
    project_doc.doc.increment('denotations_num', d_num)
    project_doc.doc.increment('blocks_num', b_num)
    project_doc.doc.increment('relations_num', r_num)
  end

  def update_project(project, d_stat_all, b_stat_all, r_stat_all)
    project.increment('denotations_num', d_stat_all)
    project.increment('blocks_num', b_stat_all)
    project.increment('relations_num', r_stat_all)
    project.update_annotations_updated_at
    project.update_updated_at
  end

  def import_denotations(project, annotations_collection)
    d_stat, instances = annotations_collection.filter { _1[:denotations].present? }
                                              .inject([Hash.new(0), []]) do |result, ann|
      docid = ann[:docid]
      instances = ann[:denotations].map do |a|
        {
          hid: a[:id],
          begin: a[:span][:begin],
          end: a[:span][:end],
          obj: a[:obj],
          project_id: project.id,
          doc_id: docid,
          is_block: a[:block_p]
        }
      end

      result[0][docid] += instances.length
      result[1] += instances

      result
    end

    return [d_stat, 0, nil] unless instances.present?

    r = Denotation.insert_all! instances
    imported_denotations = instances.map.with_index { |d, index| ["#{d[:doc_id]}#{d[:project_id]}#{d[:hid]}", r.rows[index][0]] }
                                  .to_h

    [d_stat, instances.length, imported_denotations]
  end

  def import_blocks(project, annotations_collection)
    d_stat, instances = annotations_collection.filter { _1[:blocks].present? }
                                              .inject([Hash.new(0), []]) do |result, ann|
      docid = ann[:docid]
      instances = ann[:blocks].map do |a|
        {
          hid: a[:id],
          begin: a[:span][:begin],
          end: a[:span][:end],
          obj: a[:obj],
          project_id: project.id,
          doc_id: docid
        }
      end

      result[0][docid] += instances.length
      result[1] += instances

      result
    end

    return [d_stat, 0, nil] unless instances.present?

    r = Block.insert_all! instances
    imported_blocks = instances.map.with_index { |b, index| ["#{b[:doc_id]}#{b[:project_id]}#{b[:hid]}", r.rows[index][0]] }
                                  .to_h

    [d_stat, instances.length, imported_blocks]
  end

  def import_relations(project, annotations_collection, imported_denotations, imported_blocks)
    r_stat, instances = annotations_collection.filter { _1[:relations].present? }
                                              .inject([Hash.new(0), []]) do |result, ann|
      docid = ann[:docid]

      instances = ann[:relations].map do |a|
        subj_id, subj_type = get_id_and_type_of_annotation(project, docid, a[:subj], imported_denotations, imported_blocks)
        obj_id,  obj_type  = get_id_and_type_of_annotation(project, docid, a[:obj],  imported_denotations, imported_blocks)

        {
          hid: a[:id],
          pred: a[:pred],
          subj_id: subj_id,
          subj_type: subj_type,
          obj_id: obj_id,
          obj_type: obj_type,
          project_id: project.id,
          doc_id: docid
        }
      end

      result[0][docid] += instances.length
      result[1] += instances

      result
    end

    return [r_stat, 0] unless instances.present?

    r = Relation.insert_all! instances
    imported_relations = instances.map.with_index { |a, index| ["#{a[:doc_id]}#{a[:project_id]}#{a[:hid]}", r.rows[index][0]] }
                                  .to_h

    [r_stat, instances.length, imported_relations]
  end

  def import_attributes(project, annotations_collection, imported_denotations, imported_blocks, imported_relations)
    instances = annotations_collection.filter { _1[:attributes].present? }
                                      .inject([]) do |result, ann|
      docid = ann[:docid]

      instances = ann[:attributes].map do |a|
        subj_id, subj_type = get_id_and_type_of_annotation(project, docid, a[:subj], imported_denotations, imported_blocks, imported_relations)

        {
          hid: a[:id],
          pred: a[:pred],
          subj_id: subj_id,
          subj_type: subj_type,
          obj: a[:obj],
          project_id: project.id,
          doc_id: docid
        }
      end

      result += instances

      result
    end

    return unless instances.present?

    Attrivute.insert_all! instances
  end

  def get_id_and_type_of_annotation(project, docid, hid, imported_denotations, imported_blocks = {}, imported_relations = {})
    key = "#{docid}#{project.id}#{hid}"
    id = imported_denotations[key]
    return [id, 'Denotation'] if id.present?

    id = imported_blocks[key]
    return [id, 'Block'] if id.present?

    id = imported_relations[key]
    return [id, 'Relation'] if id.present?

    raise "Unknown annotation: #{key}"
  end

  def get_id_of_annotation_from(imported_annotations, project, docid, hid)
    imported_annotations["#{docid}#{project.id}#{hid}"]
  end
end
