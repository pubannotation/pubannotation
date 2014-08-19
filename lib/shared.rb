module Shared
  # clean denotations
  def self.clean_hdenotations(denotations)
    denotations = denotations.collect {|d| d.symbolize_keys}
    ids = denotations.collect {|d| d[:id]}
    ids.compact!

    idnum = 1
    denotations.each do |a|
      return nil, "format error #{p a}" unless (a[:span] or (a[:begin] and a[:end])) and a[:obj]

      unless a.has_key? :id
        idnum += 1 until !ids.include?('T' + idnum.to_s)
        a[:id] = 'T' + idnum.to_s
        idnum += 1
      end

      if a[:span].present?
        a[:span] = a[:span].symbolize_keys
        if a[:span][:begin].class != Fixnum
          a[:span] = {begin: a[:span][:begin].to_i, end: a[:span][:end].to_i}
        end
      else
        a[:span] = Hash.new
        a[:span][:begin] = a.delete(:begin).to_i
        a[:span][:end]   = a.delete(:end).to_i
      end
    end

    [denotations, nil]
  end

  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def self.realign_denotations(denotations, from_text, to_text)
    return nil if denotations == nil

    position_map = Hash.new
    numchar, numdiff, diff = 0, 0, 0
    Diff::LCS.sdiff(from_text, to_text) do |h|
      position_map[h.old_position] = h.new_position
      numchar += 1
      if (h.new_position - h.old_position) != diff
        numdiff +=1
        diff = h.new_position - h.old_position
      end
    end
    last = from_text.length
    position_map[last] = position_map[last - 1] + 1

    # TODO
    # if (numdiff.to_f / numchar) > 2
    #   return nil, "The text is too much different from PubMed. The mapping could not be calculated.: #{numdiff}/#{numchar}"
    # else

    denotations_new = Array.new(denotations)

    (0...denotations.length).each do |i|
      denotations_new[i][:span][:begin] = position_map[denotations[i][:span][:begin]]
      denotations_new[i][:span][:end]   = position_map[denotations[i][:span][:end]]
    end

    denotations_new
  end

  def self.save_hdenotations(hdenotations, project, doc)
    hdenotations.each do |a|
      ca           = Denotation.new
      ca.hid       = a[:id]
      ca.begin     = a[:span][:begin]
      ca.end       = a[:span][:end]
      ca.obj  = a[:obj]
      ca.project_id = project.id
      ca.doc_id    = doc.id
      ca.save
    end
  end

  def self.save_hrelations(hrelations, project, doc)
    hrelations = hrelations.collect{|r| r.symbolize_keys}
    hrelations.each do |a|
      ra           = Relation.new
      ra.hid       = a[:id]
      ra.pred      = a[:pred]
      ra.subj      = Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, project.id, a[:subj])
      ra.obj       = Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, project.id, a[:obj])
      ra.project_id = project.id
      ra.save
    end
  end

  def self.save_hmodifications(hmodifications, project, doc)
    hmodifications.each do |a|
      ma        = Modification.new
      ma.hid    = a[:id]
      ma.pred   = a[:pred]
      ma.obj    = case a[:obj]
        when /^R/
          doc.subcatrels.find_by_project_id_and_hid(project.id, a[:obj])
        else
          Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, project.id, a[:obj])
      end
      ma.project_id = project.id
      ma.save
    end
  end

  def self.save_annotations(annotations, project, doc)
    denotations_old = doc.denotations.where(:project_id => project.id)
    denotations_old.destroy_all
    notice = I18n.t('controllers.application.save_annotations.annotation_cleared')
    if annotations.present? && annotations[:denotations].present?
      denotations, notice = clean_hdenotations(annotations[:denotations])
      denotations = realign_denotations(denotations, annotations[:text], doc.body)
      save_hdenotations(denotations, project, doc)

      if annotations[:relations].present?
        relations = annotations[:relations]
        relations = relations.values if relations.respond_to?(:values)
        save_hrelations(relations, project, doc)
      end

      if annotations[:modifications].present?
        modifications = annotations[:modifications]
        modifications = modifications.values if modifications.respond_to?(:values)
        save_hmodifications(modifications, project, doc)
      end

      notice = I18n.t('controllers.application.save_annotations.successfully_saved')
    end
  end
end
