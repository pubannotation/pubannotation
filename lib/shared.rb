require 'text_alignment'

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
  def self.realign_denotations(denotations, str1, str2)
    return nil if denotations.nil?
    align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)
    denotations_new = align.transform_denotations(denotations).select{|a| a[:span][:end] > a[:span][:begin]}
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

  def self.store_annotations(annotations, project, divs)
    if divs.length == 1
      self.save_annotations(annotations, project, divs[0])
    else
      divs_hash = divs.collect{|d| d.to_hash}
      div_index = TextAlignment.find_divisions(annotations[:text], divs_hash)
      p div_index
      puts "-=-=-=-=-"

      div_index.each do |i|
        p i
        if i[0] >= 0
          ann = {}
          idx = {}
          ann[:text] = annotations[:text][i[1][0] ... i[1][1]]
          if annotations[:denotations].present?
            ann[:denotations] = annotations[:denotations]
                                 .select{|a| a[:span][:begin] >= i[1][0] && a[:span][:end] <= i[1][1]}
                                .collect{|a| {:span => {:begin => a[:span][:begin] - i[1][0], :end => a[:span][:end] - i[1][0]}, :obj=>a[:obj]}}
            ann[:denotations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:relations].present?
            ann[:relations] = annotations[:relations].select{|a| idx[a[:id]]}
            ann[:relations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:relations].present?
            ann[:modifications] = annotations[:modifications].select{|a| idx[a[:id]]}
            ann[:modifications].each{|a| idx[a[:id]] = true}
          end
          self.save_annotations(ann, project, divs[i[0]])
        end
      end
    end
  end

end
