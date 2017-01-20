class Annotation < ActiveRecord::Base
  include ApplicationHelper
  include AnnotationsHelper

  def self.prepare_annotations(annotations, doc, options = {})
    annotations = align_annotations(annotations, doc)
  end

  def self.chain_spans(annotations)
    r = annotations[:denotations].inject({denotations:[], chains:[]}) do |m, d|
      if (d[:span].class == Array) && (d[:span].length > 1)
        last = d[:span].length - 1
        d[:span].each_with_index do |s, i|
          obj = (i == last) ? d[:obj] : '_FRAGMENT'
          m[:denotations] << {id:d[:id] + "-#{i}", span:s, obj:obj}
          m[:chains] << {id:'C-' + d[:id] + "-#{i-1}", pred:'_lexicallyChainedTo', subj: d[:id] + "-#{i}", obj: d[:id] + "-#{i-1}"} if i > 0
        end
      else
        m[:denotations] << d
      end
      m
    end

    denotations = r[:denotations]
    chains = r[:chains]

    annotations[:denotations] = denotations
    unless chains.empty?
      annotations[:relations] ||=[]
      annotations[:relations] += chains
    end
    annotations
  end

  def self.bag_spans(annotations)
    denotations = annotations[:denotations]
    relations = annotations[:relations]

    tomerge = Hash.new

    new_relations = Array.new
    relations.each do |ra|
      if ra[:pred] == '_lexicallyChainedTo'
        tomerge[ra[:obj]] = ra[:subj]
      else
        new_relations << ra
      end
    end
    idx = Hash.new
    denotations.each_with_index {|ca, i| idx[ca[:id]] = i}

    mergedto = Hash.new
    tomerge.each do |from, to|
      to = mergedto[to] if mergedto.has_key?(to)
      fca = denotations[idx[from]]
      tca = denotations[idx[to]]
      tca[:span] = [tca[:span]] unless tca[:span].respond_to?('push')
      tca[:span].push (fca[:span])
      denotations.delete_at(idx[from])
      mergedto[from] = to
    end

    annotations[:denotations] = denotations
    annotations[:relations] = new_relations
    annotations
  end

  def self.bag_denotations(denotations, relations)
    tomerge = Hash.new

    new_relations = Array.new
    relations.each do |ra|
      if ra[:pred] == '_lexicallyChainedTo'
        tomerge[ra[:obj]] = ra[:subj]
      else
        new_relations << ra
      end
    end
    idx = Hash.new
    denotations.each_with_index {|ca, i| idx[ca[:id]] = i}

    mergedto = Hash.new
    tomerge.each do |from, to|
      to = mergedto[to] if mergedto.has_key?(to)
      fca = denotations[idx[from]]
      tca = denotations[idx[to]]
      tca[:span] = [tca[:span]] unless tca[:span].respond_to?('push')
      tca[:span].push (fca[:span])
      denotations.delete_at(idx[from])
      mergedto[from] = to
    end

    return denotations, new_relations
  end

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

  def self.prepare_annotations_divs(annotations, divs)
    if divs.length == 1
      [prepare_annotations(annotations, divs[0])]
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
          annotations_collection << prepare_annotations(ann, div_index[i[0]])
        end
      end
      # {div_index: fit_index}
      annotations_collection
    end
  end

end