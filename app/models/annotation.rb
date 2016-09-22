class Annotation < ActiveRecord::Base
  include ApplicationHelper
  include AnnotationsHelper

  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def self.align_denotations(denotations, str1, str2)
    return nil if denotations.nil?
    align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)
    align.transform_hdenotations(denotations).select{|a| a[:span][:begin].to_i <= a[:span][:end].to_i }
  end

  def self.align_annotations(annotations, doc)
    original_text = annotations[:text]
    annotations[:text] = doc.original_body.nil? ? doc.body : doc.original_body

    if annotations[:denotations].present?
      num = annotations[:denotations].length
      annotations[:denotations] = align_denotations(annotations[:denotations], original_text, annotations[:text])
      raise "Alignment failed. Text may be too much different." if annotations[:denotations].length < num
      annotations[:denotations].each{|d| raise "Alignment failed. Text may be too much different." if d[:span][:begin].nil? || d[:span][:end].nil?}
    end

    annotations.select{|k,v| v.present?}
  end

  def self.align_annotations_divs(annotations, divs)
    if divs.length == 1
      [align_annotations(annotations, divs[0])]
    else
      annotations_collection = []

      div_index = divs.collect{|d| [d.serial, d]}.to_h
      divs_hash = divs.collect{|d| d.to_hash}
      fit_index = TextAlignment.find_divisions(annotations[:text], divs_hash)

      fit_index.each do |i|
        if i[0] >= 0
          ann = {sourcedb:annotations[:sourcedb], sourceid:annotations[:sourceid], divid:i[0]}
          idx = {}
          ann[:text] = annotations[:text][i[1][0] ... i[1][1]]
          if annotations[:denotations].present?
            ann[:denotations] = annotations[:denotations]
                                 .select{|a| a[:span][:begin] >= i[1][0] && a[:span][:end] <= i[1][1]}
                                .collect{|a| n = a.dup; n[:span] = a[:span].dup; n}
                                   .each{|a| a[:span][:begin] -= i[1][0]; a[:span][:end] -= i[1][0]}
            ann[:denotations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:relations].present?
            ann[:relations] = annotations[:relations].select{|a| idx[a[:subj]] && idx[a[:obj]]}
            ann[:relations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:modifications].present?
            ann[:modifications] = annotations[:modifications].select{|a| idx[a[:obj]]}
            ann[:modifications].each{|a| idx[a[:id]] = true}
          end
          annotations_collection << align_annotations(ann, div_index[i[0]])
        end
      end
      # {div_index: fit_index}
      annotations_collection
    end
  end

end