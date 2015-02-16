require 'text_alignment'

module Shared
  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def self.align_denotations(denotations, str1, str2)
    return nil if denotations.nil?
    align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)
    align.transform_hdenotations(denotations).select{|a| a[:span][:end].to_i > a[:span][:begin].to_i}
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
      raise "could not save #{ra.hid}" unless ca.save
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
      raise "could not save #{ra.hid}" unless ra.save
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
      raise "could not save #{ma.hid}" unless ma.save
    end
  end

  def self.save_annotations(annotations, project, doc, options = nil)
    if project.present? && doc.present?
      doc.destroy_project_annotations(project) unless options.present? && options[:mode] == :addition

      original_text = annotations[:text]
      annotations[:text] = doc.body

      if annotations[:denotations].present?
        annotations[:denotations] = align_denotations(annotations[:denotations], original_text, annotations[:text])
        ActiveRecord::Base.transaction do
          save_hdenotations(annotations[:denotations], project, doc)
          save_hrelations(annotations[:relations], project, doc) if annotations[:relations].present?
          save_hmodifications(annotations[:modifications], project, doc) if annotations[:modifications].present?
        end
      end
    end

    annotations.select{|k,v| v.present?}
  end

  def self.store_annotations(annotations, project, divs, options = {})
    options ||= {}
    successful = true
    fit_index = nil

    begin
      if divs.length == 1
        result = self.save_annotations(annotations, project, divs[0], options)
      else
        result = []
        div_index = divs.collect{|d| [d.serial, d]}.to_h
        divs_hash = divs.collect{|d| d.to_hash}
        fit_index = TextAlignment.find_divisions(annotations[:text], divs_hash)

        fit_index.each do |i|
          if i[0] >= 0
            ann = {divid:i[0]}
            idx = {}
            ann[:text] = annotations[:text][i[1][0] ... i[1][1]]
            if annotations[:denotations].present?
              ann[:denotations] = annotations[:denotations]
                                   .select{|a| a[:span][:begin] >= i[1][0] && a[:span][:end] <= i[1][1]}
                                  .collect{|a| a.dup}
                                     .each{|a| a[:span][:begin] -= i[1][0]; a[:span][:end] -= i[1][0]}
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
            result << self.save_annotations(ann, project, div_index[i[0]], options)
          end
        end
        {div_index: fit_index}
      end
    rescue => e
      successful = false
      result = nil
    end

    project.notices.create({method: "- upload annotations: #{divs[0].sourcedb}:#{divs[0].sourceid}", successful: successful}) if options[:delayed]
    result 
  end

end
