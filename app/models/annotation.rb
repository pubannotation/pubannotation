class Annotation < ActiveRecord::Base
  include ApplicationHelper
  include AnnotationsHelper

  # To produce an array of annotations for export.
  # The initial row of the array to contain the headers
  def self.hash_to_array(annotations, textae_config = nil)
    array = []

    headers = ["Id", "Subject", "Object", "Predicate", "Lexical cue"]

    text = annotations[:text]
    lexical_cues = {}

    attrs_idx = nil
    attr_preds = []

    if annotations[:attributes].present?
      attrs = annotations[:attributes]
      attrs_idx = attrs.inject({}) do |idx, a|
        idx.merge("#{a[:subj]}&#{a[:pred]}" => a)
      end
      attr_preds = if textae_config.present? && textae_config[:"attribute types"].present?
        textae_config[:"attribute types"].collect{|t| t[:pred]}
      else
        attrs.collect{|a| a[:pred]}.uniq.sort
      end
    end

    array << headers + attr_preds

    if annotations[:denotations].present?
      annotations[:denotations].each do |a|
        spans = a[:span].class == Array ? a[:span] : [a[:span]]
        lexical_cues[a[:id]] = spans.collect{|s| text[s[:begin]...s[:end]]}.join(' ').chomp
        spant = spans.collect{|s| "#{s[:begin]}-#{s[:end]}"}.to_csv.chomp
        attrs = attr_preds.collect do |pred|
          att = attrs_idx["#{a[:id]}&#{pred}"]
          att.nil? ? nil : att[:obj]
        end
        array << [a[:id], spant, a[:obj], 'denotes', lexical_cues[a[:id]]] + attrs
      end
    end

    if annotations[:relations].present?
      annotations[:relations].each do |a|
        lexical_cues[a[:id]] = [lexical_cues[a[:subj]], lexical_cues[a[:obj]]].to_csv.chomp
        array << [a[:id], a[:subj], a[:obj], a[:pred], lexical_cues[a[:id]]]
      end
    end

    if annotations[:modifications].present?
      annotations[:modifications].each do |a|
        array << [a[:id], a[:obj], a[:pred], 'hasMood', lexical_cues[a[:obj]]]
      end
    end

    array
  end

  def self.hash_to_tsv(annotations, textae_config = nil)
    array = self.hash_to_array(annotations, textae_config)
    array[0][0] = '# ' + array[0][0]
    tsv = CSV.generate(col_sep:"\t") do |csv|
      array.each{|a| csv << a}
    end
    return tsv
  end

  def self.hash_to_dic_array(annotations)
    array = []

    headers = ["Term", "Identifier"]
    array << headers

    text = annotations[:text]
    if annotations[:denotations].present?
      annotations[:denotations].each do |a|
        spans = a[:span].class == Array ? a[:span] : [a[:span]]
        lexical_cue = spans.collect{|s| text[s[:begin]...s[:end]]}.join(' ').chomp
        array << [lexical_cue, a[:obj]]
      end
    end

    array.uniq
  end

  def self.dic_array_to_tsv(dic)
    dic[0][0] = '# ' + dic[0][0]
    CSV.generate(col_sep:"\t") do |csv|
      dic.each{|a| csv << a}
    end
  end

  def self.hash_to_dic(annotations)
    array = self.hash_to_dic_array(annotations)
    self.dic_array_to_tsv(array)
  end

  # normalize annotations passed by an HTTP call
  def self.normalize!(annotations, prefix = nil)
    raise ArgumentError, "annotations must be a hash." unless annotations.class == Hash
    raise ArgumentError, "annotations must include a 'text'"  unless annotations[:text].present?

    if annotations[:sourcedb].present?
      annotations[:sourcedb] = 'PubMed' if annotations[:sourcedb].downcase == 'pubmed'
      annotations[:sourcedb] = 'PMC' if annotations[:sourcedb].downcase == 'pmc'
      annotations[:sourcedb] = 'FirstAuthors' if annotations[:sourcedb].downcase == 'firstauthors'
    end

    if annotations[:denotations].present?
      raise ArgumentError, "'denotations' must be an array." unless annotations[:denotations].class == Array
      annotations[:denotations].each{|d| d = d.symbolize_keys}

      annotations = Annotation.chain_spans(annotations)

      ids = annotations[:denotations].collect{|d| d[:id]}.compact
      idnum = 1

      annotations[:denotations].each do |a|
        raise ArgumentError, "a denotation must have a 'span' or a pair of 'begin' and 'end'." unless (a[:span].present? && a[:span][:begin].present? && a[:span][:end].present?) || (a[:begin].present? && a[:end].present?)
        raise ArgumentError, "a denotation must have an 'obj'." unless a[:obj].present?

        unless a.has_key? :id
          idnum += 1 until !ids.include?('T' + idnum.to_s)
          a[:id] = 'T' + idnum.to_s
          idnum += 1
        end

        a[:span] = {begin: a[:begin], end: a[:end]} if !a[:span].present? && a[:begin].present? && a[:end].present?

        a[:span][:begin] = a[:span][:begin].to_i if a[:span][:begin].is_a? String
        a[:span][:end]   = a[:span][:end].to_i   if a[:span][:end].is_a? String

        raise ArgumentError, "the begin offset must be between 0 and the length of the text: #{a}" if a[:span][:begin] < 0 || a[:span][:begin] > annotations[:text].length
        raise ArgumentError, "the end offset must be between 0 and the length of the text." if a[:span][:end] < 0 || a[:span][:end] > annotations[:text].length
        raise ArgumentError, "the begin offset must not be bigger than the end offset." if a[:span][:begin] > a[:span][:end]
      end
    end

    d_ids = nil

    if annotations[:relations].present?
      raise ArgumentError, "'relations' must be an array." unless annotations[:relations].class == Array

      d_ids = annotations[:denotations].collect{|a| a[:id]}

      annotations[:relations].each{|a| a = a.symbolize_keys}

      ids = annotations[:relations].collect{|a| a[:id]}.compact
      idnum = 1

      annotations[:relations].each do |a|
        raise ArgumentError, "a relation must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
        raise ArgumentError, "'subj' and 'obj' of a relation must reference to a denotation: [#{a}]." unless (d_ids.include? a[:subj]) && (d_ids.include? a[:obj])

        unless a.has_key? :id
          idnum += 1 until !ids.include?('R' + idnum.to_s)
          a[:id] = 'R' + idnum.to_s
          idnum += 1
        end
      end
    end

    if annotations[:attributes].present?
      raise ArgumentError, "'attributes' must be an array." unless annotations[:attributes].class == Array
      annotations[:attributes].each{|a| a = a.symbolize_keys}

      d_ids ||= annotations[:denotations].collect{|a| a[:id]}

      ids = annotations[:attributes].collect{|a| a[:id]}.compact
      idnum = 1

      annotations[:attributes].each do |a|

        # TODO: to remove the following line after TextAE is updated.
        a[:obj] = true unless a[:obj].present?

        raise ArgumentError, "An attribute must have 'subj', 'obj' and 'pred'." unless a[:subj].present? && a[:obj].present? && a[:pred].present?
        raise ArgumentError, "The 'subj' of an attribute must reference to a denotation: [#{a}]." unless d_ids.include? a[:subj]

        unless a.has_key? :id
          idnum += 1 until !ids.include?('A' + idnum.to_s)
          a[:id] = 'A' + idnum.to_s
          idnum += 1
        end
      end
    end

    if annotations[:modifications].present?
      raise ArgumentError, "'modifications' must be an array." unless annotations[:modifications].class == Array
      annotations[:modifications].each{|a| a = a.symbolize_keys}

      d_ids ||= annotations[:denotations].collect{|a| a[:id]}
      dr_ids = d_ids + annotations[:relations].collect{|a| a[:id]}

      ids = annotations[:modifications].collect{|a| a[:id]}.compact
      idnum = 1

      annotations[:modifications].each do |a|
        raise ArgumentError, "A modification must have 'pred' and 'obj'." unless a[:pred].present? && a[:obj].present?
        raise ArgumentError, "The 'obj' of a modification must reference to a denotation or a relation: [#{a}]." unless dr_ids.include? a[:obj]

        unless a.has_key? :id
          idnum += 1 until !ids.include?('M' + idnum.to_s)
          a[:id] = 'M' + idnum.to_s
          idnum += 1
        end
      end
    end

    if prefix.present?
      annotations[:denotations].each {|a| a[:id] = prefix + '_' + a[:id]} if annotations[:denotations].present?
      annotations[:relations].each {|a| a[:id] = prefix + '_' + a[:id]; a[:subj] = prefix + '_' + a[:subj]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:relations].present?
      annotations[:attributes].each {|a| a[:id] = prefix + '_' + a[:id]; a[:subj] = prefix + '_' + a[:subj]} if annotations[:attributes].present?
      annotations[:modifications].each {|a| a[:id] = prefix + '_' + a[:id]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:modifications].present?
    end

    annotations
  end

  def self.prepare_annotations(annotations, doc, options = {})
    annotations = align_annotations(annotations, doc, options[:span])
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
      fda = denotations[idx[from]]
      tda = denotations[idx[to]]
      tda[:span] = [tca[:span]] unless tca[:span].respond_to?('push')
      tca[:span].push (fca[:span])
      denotations.delete_at(idx[from])
      mergedto[from] = to
    end

    annotations[:denotations] = denotations
    annotations[:relations] = new_relations
    annotations
  end

  def self.bag_denotations(denotations, relations)
    mergedto = {}
    relations.each do |ra|
      if ra[:pred] == '_lexicallyChainedTo'
        # To see if either subjet or object is already merged to another.
        ra[:subj] = mergedto[ra[:subj]] if mergedto.has_key? ra[:subj]
        ra[:obj] = mergedto[ra[:obj]] if mergedto.has_key? ra[:obj]

        # To find the indice of the subject and object
        idx_from = denotations.find_index{|d| d[:id] == ra[:subj]}
        idx_to   = denotations.find_index{|d| d[:id] == ra[:obj]}
        from = denotations[idx_from]
        to   = denotations[idx_to]

        from[:span] = [from[:span]] unless from[:span].respond_to?('push')
        to[:span]   = [to[:span]]   unless to[:span].respond_to?('push')

        # To merge the two spans (in the reverse order)
        from[:span] = to[:span] + from[:span]
        denotations.delete_at(idx_to)
        mergedto[ra[:obj]] = ra[:subj]
      end
    end
    relations.delete_if{|ra| ra[:pred] == '_lexicallyChainedTo'}

    return denotations, relations
  end

  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def self.align_denotations(denotations, str1, str2)
    return nil if denotations.nil?
    align = TextAlignment::TextAlignment.new(str1, str2, TextAlignment::MAPPINGS)
    denotations_new = align.transform_hdenotations(denotations)
    bads = denotations_new.select{|d| d[:span][:begin].nil? || d[:span][:end].nil? || d[:span][:begin].to_i >= d[:span][:end].to_i}
    unless bads.empty? && align.similarity > 0.5
      align = TextAlignment::TextAlignment.new(str1.downcase, str2.downcase, TextAlignment::MAPPINGS)
      denotations_new = align.transform_hdenotations(denotations)
      bads = denotations_new.select{|d| d[:span][:begin].nil? || d[:span][:end].nil? || d[:span][:begin].to_i >= d[:span][:end].to_i}
      raise "Alignment failed. Text may be too much different." unless bads.empty?
    end
    denotations_new
  end

  # To align annotations, considering the span specification
  def self.align_annotations(annotations, doc, span = nil)
    if annotations[:denotations].present?
      if span
        raise ArgumentError, "The text of the span might be changed, which is not allowed when the span is explictely specified in the URL." if annotations[:text] != doc.body[span[:begin] ... span[:end]]
        annotations[:denotations].each do |d|
          d[:span][:begin] += span[:begin]
          d[:span][:end]   += span[:begin]
        end
        annotations[:text] = doc.body
      end

      target_text = doc.original_body.nil? ? doc.body : doc.original_body
      if annotations[:text] != target_text
        annotations[:denotations] = align_denotations(annotations[:denotations], annotations[:text], target_text)
      end
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
      fit_index.each_with_index do |f, i|
        gap = []
        (0 .. i).each{|j| gap << fit_index[j][1] if f[1][0] < fit_index[j][1][0] && f[1][1] > fit_index[j][1][1]}
        f << gap
      end

      fit_index.each do |fit|
        if fit[0] >= 0
          ann = {sourcedb:annotations[:sourcedb], sourceid:annotations[:sourceid], divid:fit[0]}
          ann[:text] = ''
          ann[:denotations] = [] if annotations[:denotations]

          offsets = (fit[1] + fit[2].flatten).sort
          offsets.each_slice(2) do |a, b|
            if annotations[:denotations].present?
              base = a - ann[:text].length
              ann_col = annotations[:denotations].select{|d| d[:span][:begin] >= a && d[:span][:end] <= b}.collect{|d| d.dup}
              ann_col.each{|d| d[:span] = {begin: d[:span][:begin] - base, end: d[:span][:end] - base}}
              ann[:denotations] += ann_col
            end
            ann[:text] += annotations[:text][a ... b]
          end

          if ann[:denotations]
            idx = {}
            ann[:denotations].each{|a| idx[a[:id]] = true}
            if annotations[:relations].present?
              ann[:relations] = annotations[:relations].select{|a| idx[a[:subj]] && idx[a[:obj]]}
              ann[:relations].each{|a| idx[a[:id]] = true}
            end
            if annotations[:modifications].present?
              ann[:modifications] = annotations[:modifications].select{|a| idx[a[:obj]]}
              ann[:modifications].each{|a| idx[a[:id]] = true}
            end
          end
          annotations_collection << prepare_annotations(ann, div_index[fit[0]])
        end
      end
      # {div_index: fit_index}
      annotations_collection
    end
  end

end
