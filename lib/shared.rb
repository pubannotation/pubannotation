require 'text_alignment'

module Shared
  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def self.align_denotations(denotations, str1, str2)
    return nil if denotations.nil?
    align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)

    p str1
    puts "----------"
    p str2
    puts "=========="
    p align

    denotations_new = align.transform_denotations(denotations).select{|a| a[:span][:end].to_i > a[:span][:begin].to_i}
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

  def self.save_annotations(annotations, project, doc, options = nil)
    doc.clear_annotations(project) unless options.present? && options[:mode] == :addition

    if annotations[:denotations].present?
      denotations = align_denotations(annotations[:denotations], annotations[:text], doc.body)
      save_hdenotations(denotations, project, doc)

      if annotations[:relations].present?
        # relations = relations.values if relations.respond_to?(:values)
        save_hrelations(annotations[:relations], project, doc)
      end

      if annotations[:modifications].present?
        # modifications = modifications.values if modifications.respond_to?(:values)
        save_hmodifications(annotations[:modifications], project, doc)
      end

    end
  end

  def self.store_annotations(annotations, project, divs, options = nil)
    successful = true
    fit_index = nil
    begin
      div_index = divs.map{|d| [d.serial, d]}.to_h

      if divs.length == 1
        self.save_annotations(annotations, project, divs[0], options)
      else
        div_index = divs.collect{|d| [d.serial, d]}.to_h
        divs_hash = divs.collect{|d| d.to_hash}
        fit_index = TextAlignment.find_divisions(annotations[:text], divs_hash)

        fit_index.each do |i|
          if i[0] >= 0
            ann = {}
            idx = {}
            ann[:text] = annotations[:text][i[1][0] ... i[1][1]]
            if annotations[:denotations].present?
              ann[:denotations] = annotations[:denotations]
                                   .select{|a| a[:span][:begin] >= i[1][0] && a[:span][:end] <= i[1][1]}
                                  .collect{|a| {:span => {:begin => a[:span][:begin] - i[1][0], :end => a[:span][:end] - i[1][0]}, :obj => a[:obj]}}
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
            self.save_annotations(ann, project, div_index[i[0]], options)
          end
        end
        fit_index
      end
    rescue => e
      p e.message
      successful = false
    end
    project.notices.create({successful: successful, method: 'store_annotations'}) if options[:delayed]
    return fit_index 
  end

end
