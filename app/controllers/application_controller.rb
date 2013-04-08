# encoding: UTF-8
require 'pmcdoc'
require 'utfrewrite'
require 'aligner'

class ApplicationController < ActionController::Base
  protect_from_forgery

  # def after_sign_in_path_for(resource)
  # end

  def after_sign_out_path_for(resource_or_scope)
    request.referrer
  end

  def get_docspec(params)
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
      serial   = 0
    elsif params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
      serial   = params[:div_id]
    else
      sourcedb = nil
      sourceid = nil
      serial   = nil
    end

    return sourcedb, sourceid, serial
  end


  def get_annset (annset_name)
    annset = Annset.find_by_name(annset_name)
    if annset
      if (annset.accessibility == 1 or (user_signed_in? and annset.user == current_user))
        return annset, nil
      else
        return nil, "The annotation set, #{annset_name}, is specified as private."
      end
    else
      return nil, "The annotation set, #{annset_name}, does not exist."
    end
  end


  def get_annsets (doc = nil)
    annsets = (doc)? doc.annsets : Annset.all
    annsets.sort!{|x, y| x.name <=> y.name}
    annsets = annsets.keep_if{|a| a.accessibility == 1 or (user_signed_in? and a.user == current_user)}
  end


  def get_doc (sourcedb, sourceid, serial = 0, annset = nil)
    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    if doc
      if annset and !doc.annsets.include?(annset)
        doc = nil
        notice = "The document, #{sourcedb}:#{sourceid}, does not belong to the annotation set, #{annset.name}."
      end
    else
      notice = "No annotation to the document, #{sourcedb}:#{sourceid}, exists in PubAnnotation." 
    end

    return doc, notice
  end


  def get_divs (sourceid, annset = nil)
    divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', sourceid)
    if divs and !divs.empty?
      if annset and !divs.first.annsets.include?(annset)
        divs = nil
        notice = "The document, PMC::#{sourceid}, does not belong to the annotation set, #{annset.name}."
      end
    else
      divs = nil
      notice = "No annotation to the document, PMC:#{sourceid}, exists in PubAnnotation." 
    end

    return [divs, notice]
  end


  def rewrite_ascii (docs)
    docs.each do |doc|
      doc.body = get_ascii_text(doc.body)
    end
    docs
  end


  ## get a pmdoc from pubmed
  def gen_pmdoc (pmid)
    RestClient.get "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&id=#{pmid}" do |response, request, result|
      case response.code
      when 200
        parser   = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        doc      = parser.parse
        result   = doc.find_first('/PubmedArticleSet').content.strip
        return nil if result.empty?
        title    = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle')
        abstract = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText')
        doc      = Doc.new
        doc.body = ""
        doc.body += title.content.strip if title
        doc.body += "\n" + abstract.content.strip if abstract
        doc.source = 'http://www.ncbi.nlm.nih.gov/pubmed/' + pmid
        doc.sourcedb = 'PubMed'
        doc.sourceid = pmid
        doc.serial = 0
        doc.section = 'TIAB'
        doc.save
        return doc
      else
        return nil
      end
    end
  end


  ## get a pmcdoc from pubmed central
  def gen_pmcdoc (pmcid)
    pmcdoc = PMCDoc.new(pmcid)

    if pmcdoc.doc
      divs = pmcdoc.get_divs
      if divs
        docs = []
        divs.each_with_index do |div, i|
          doc = Doc.new
          doc.body = div[1]
          doc.source = 'http://www.ncbi.nlm.nih.gov/pmc/' + pmcid
          doc.sourcedb = 'PMC'
          doc.sourceid = pmcid
          doc.serial = i
          doc.section = div[0]
          doc.save
          docs << doc
        end
        return [docs, nil]
      else
        return [nil, "no body in the document."]
      end
    else
      return [nil, pmcdoc.message]
    end
  end


  def archive_texts (docs)
    unless docs.empty
      file_name = "docs.zip"
      t = Tempfile.new("my-temp-filename-#{Time.now}")
      Zip::ZipOutputStream.open(t.path) do |z|
        docs.each do |doc|
          # title = "#{doc.sourcedb}-#{doc.sourceid}-%02d-#{doc.section}" % doc.serial
          title = "%s-%s-%02d-%s" % [doc.sourcedb, doc.sourceid, doc.serial, doc.section]
          title.sub!(/\.$/, '')
          title.gsub!(' ', '_')
          title += ".txt" unless title.end_with?(".txt")
          z.put_next_entry(title)
          z.print doc.body
        end
      end
      send_file t.path, :type => 'application/zip',
                             :disposition => 'attachment',
                             :filename => file_name
      t.close
    end
  end


  def archive_annotation (annset_name, format = 'json')
    annset = Annset.find_by_name(annset_name)
    annset.docs.each do |d|
    end
  end


  def get_conversion (annotation, converter, identifier = nil)
    RestClient.post converter, {:annotation => annotation.to_json}, :content_type => :json, :accept => :json do |response, request, result|
      case response.code
      when 200
        response
      else
        nil
      end
    end
  end


  def gen_annotations (annotation, annserver, identifier = nil)
    RestClient.post annserver, {:annotation => annotation.to_json}, :content_type => :json, :accept => :json do |response, request, result|
      case response.code
      when 200
        annotations = JSON.parse response, :symbolize_names => true
      else
        nil
      end
    end
  end


  def get_annotations (annset, doc, options = {})
    if annset and doc
      catanns = doc.catanns.where("annset_id = ?", annset.id).order('begin ASC')
      hcatanns = catanns.collect {|ca| ca.get_hash} unless catanns.empty?

      insanns = doc.insanns.where("insanns.annset_id = ?", annset.id)
      insanns.sort! {|i1, i2| i1.hid[1..-1].to_i <=> i2.hid[1..-1].to_i}
      hinsanns = insanns.collect {|ia| ia.get_hash} unless insanns.empty?

      relanns  = doc.subcatrels.where("relanns.annset_id = ?", annset.id)
      relanns += doc.subinsrels.where("relanns.annset_id = ?", annset.id)
      relanns.sort! {|r1, r2| r1.hid[1..-1].to_i <=> r2.hid[1..-1].to_i}
      hrelanns = relanns.collect {|ra| ra.get_hash} unless relanns.empty?

      modanns = doc.insmods.where("modanns.annset_id = ?", annset.id)
      modanns += doc.subcatrelmods.where("modanns.annset_id = ?", annset.id)
      modanns += doc.subinsrelmods.where("modanns.annset_id = ?", annset.id)
      modanns.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      hmodanns = modanns.collect {|ma| ma.get_hash} unless modanns.empty?

      text = doc.body
      if (options[:encoding] == 'ascii')
        asciitext = get_ascii_text (text)
        aligner = Aligner.new(text, asciitext, [["Δ", "delta"], [" ", " "], ["−", "-"], ["–", "-"], ["′", "'"], ["’", "'"]])
        # aligner = Aligner.new(text, asciitext)
        hcatanns = aligner.transform_catanns(hcatanns)
        # hcatanns = adjust_catanns(hcatanns, asciitext)
        text = asciitext
      end

      if (options[:discontinuous_annotation] == 'bag')
        # TODO: convert to hash representation
        hcatanns, hrelanns = bag_catanns(hcatanns, hrelanns)
      end

      annotations = Hash.new
      # if doc.sourcedb == 'PudMed'
      #   annotations[:pmdoc_id] = doc.sourceid
      # elsif doc.sourcedb == 'PMC'
      #   annotations[:pmcdoc_id] = doc.sourceid
      #   annotations[:div_id] = doc.serial
      # end
      annotations[:source_db] = doc.sourcedb
      annotations[:source_id] = doc.sourceid
      annotations[:division_id] = doc.serial
      annotations[:section] = doc.section
      annotations[:text] = text
      annotations[:catanns] = hcatanns if hcatanns
      annotations[:insanns] = hinsanns if hinsanns
      annotations[:relanns] = hrelanns if hrelanns
      annotations[:modanns] = hmodanns if hmodanns
      annotations
    else
      nil
    end
  end


  def save_annotations (annotations, annset, doc)
    catanns, notice = clean_hcatanns(annotations[:catanns])
    if catanns
      catanns = realign_catanns(catanns, annotations[:text], doc.body)

      if catanns
        catanns_old = doc.catanns.where("annset_id = ?", annset.id)
        catanns_old.destroy_all
      
        save_hcatanns(catanns, annset, doc)

        if annotations[:insanns] and !annotations[:insanns].empty?
          insanns = annotations[:insanns]
          insanns = insanns.values if insanns.respond_to?(:values)
          save_hinsanns(insanns, annset, doc)
        end

        if annotations[:relanns] and !annotations[:relanns].empty?
          relanns = annotations[:relanns]
          relanns = relanns.values if relanns.respond_to?(:values)
          save_hrelanns(relanns, annset, doc)
        end

        if annotations[:modanns] and !annotations[:modanns].empty?
          modanns = annotations[:modanns]
          modanns = modanns.values if modanns.respond_to?(:values)
          save_hmodanns(modanns, annset, doc)
        end

        notice = 'Annotations were successfully created/updated.'
      end
    end

    notice
  end


  ## get catanns
  def get_catanns (annset_name, sourcedb, sourceid, serial = 0)
    catanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        catanns = doc.catanns.where("annset_id = ?", annset.id).order('begin ASC')
      else
        catanns = doc.catanns
      end
    else
      if annset_name and annset = Annset.find_by_name(annset_name)
        catanns = annset.catanns
      else
        catanns = Catann.all
      end
    end

    catanns
  end


  # get catanns (hash version)
  def get_hcatanns (annset_name, sourcedb, sourceid, serial = 0)
    catanns = get_catanns(annset_name, sourcedb, sourceid, serial)
    hcatanns = catanns.collect {|ca| ca.get_hash}
    hcatanns
  end


  def clean_hcatanns (catanns)
    catanns = catanns.values if catanns.respond_to?(:values)
    ids = catanns.collect {|a| a[:id] or a["id"]}
    ids.compact!

    idnum = 1
    catanns.each do |a|
      return nil, "format error" unless (a[:span] or (a[:begin] and a[:end])) and a[:category]

      unless a[:id]
        idnum += 1 until !ids.include?('T' + idnum.to_s)
        a[:id] = 'T' + idnum.to_s
        idnum += 1
      end

      if a[:span]
        a[:span][:begin] = a[:span][:begin].to_i
        a[:span][:end]   = a[:span][:end].to_i
      else
        a[:span] = Hash.new
        a[:span][:begin] = a.delete(:begin).to_i
        a[:span][:end]   = a.delete(:end).to_i
      end
    end

    [catanns, nil]
  end


  def save_hcatanns (hcatanns, annset, doc)
    hcatanns.each do |a|
      ca           = Catann.new
      ca.hid       = a[:id]
      ca.begin     = a[:span][:begin]
      ca.end       = a[:span][:end]
      ca.category  = a[:category]
      ca.annset_id = annset.id
      ca.doc_id    = doc.id
      ca.save
    end
  end


  def chain_catanns (catanns_s)
    mid = 0
    catanns_s.each do |ca|
      if (cid = a.hid[1..-1].to_i) > mid 
        mid = cid
      end
    end
  end


  def bag_catanns (catanns, relanns)
    tomerge = Hash.new

    new_relanns = Array.new
    relanns.each do |ra|
      if ra.type == 'lexChain'
        tomerge[ra.object] = ra.subject
      else
        new_relanns << ra
      end
    end
    idx = Hash.new
    catanns.each_with_index {|ca, i| idx[ca.id] = i}

    mergedto = Hash.new
    tomerge.each do |from, to|
      to = mergedto[to] if mergedto.has_key?(to)
      p idx[from]
      fca = catanns[idx[from]]
      tca = catanns[idx[to]]
      tca.span = [tca.span] unless tca.span.respond_to?('push')
      tca.span.push (fca.span)
      catanns.delete_at(idx[from])
      mergedto[from] = to
    end

    return catanns, new_relanns
  end


  ## get insanns
  def get_insanns (annset_name, sourcedb, sourceid, serial = 0)
    insanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        insanns = doc.insanns.where("insanns.annset_id = ?", annset.id)
        insanns.sort! {|i1, i2| i1.hid[1..-1].to_i <=> i2.hid[1..-1].to_i}
      else
        insanns = doc.insanns
      end
    else
      if annset_name and annset = Annset.find_by_name(annset_name)
        insanns = annset.insanns
      else
        insanns = Insann.all
      end
    end

    insanns
  end


  # get insanns (hash version)
  def get_hinsanns (annset_name, sourcedb, sourceid, serial = 0)
    insanns = get_insanns(annset_name, sourcedb, sourceid, serial)
    hinsanns = insanns.collect {|ia| ia.get_hash}
  end


  def save_hinsanns (hinsanns, annset, doc)
    hinsanns.each do |a|
      ia           = Insann.new
      ia.hid       = a[:id]
      ia.instype   = a[:type]
      ia.insobj    = Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:object])
      ia.annset_id = annset.id
      ia.save
    end
  end


  ## get relanns
  def get_relanns (annset_name, sourcedb, sourceid, serial = 0)
    relanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        relanns  = doc.subcatrels.where("relanns.annset_id = ?", annset.id)
        relanns += doc.subinsrels.where("relanns.annset_id = ?", annset.id)
        relanns.sort! {|r1, r2| r1.hid[1..-1].to_i <=> r2.hid[1..-1].to_i}
#        relanns += doc.objcatrels.where("relanns.annset_id = ?", annset.id)
#        relanns += doc.objinsrels.where("relanns.annset_id = ?", annset.id)
      else
        relanns = doc.subcatrels + doc.subinsrels unless doc.catanns.empty?
      end
    else
      if annset_name and annset = Annset.find_by_name(annset_name)
        relanns = annset.relanns
      else
        relanns = Relann.all
      end
    end

    relanns
  end


  # get relanns (hash version)
  def get_hrelanns (annset_name, sourcedb, sourceid, serial = 0)
    relanns = get_relanns(annset_name, sourcedb, sourceid, serial)
    hrelanns = relanns.collect {|ra| ra.get_hash}
  end


  def save_hrelanns (hrelanns, annset, doc)
    hrelanns.each do |a|
      ra           = Relann.new
      ra.hid       = a[:id]
      ra.reltype   = a[:type]
      ra.relsub    = case a[:subject]
        when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:subject])
        else           doc.insanns.find_by_annset_id_and_hid(annset.id, a[:subject])
      end
      ra.relobj    = case a[:object]
        when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:object])
        else           doc.insanns.find_by_annset_id_and_hid(annset.id, a[:object])
      end
      ra.annset_id = annset.id
      ra.save
    end
  end


  ## get modanns
  def get_modanns (annset_name, sourcedb, sourceid, serial = 0)
    modanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        modanns = doc.insmods.where("modanns.annset_id = ?", annset.id)
        modanns += doc.subcatrelmods.where("modanns.annset_id = ?", annset.id)
        modanns += doc.subinsrelmods.where("modanns.annset_id = ?", annset.id)
        modanns.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      else
        #modanns = doc.modanns unless doc.catanns.empty?
        modanns = doc.insmods
        modanns += doc.subcatrelmods
        modanns += doc.subinsrelmods
        modanns.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      end
    else
      if annset_name and annset = Annset.find_by_name(annset_name)
        modanns = annset.modanns
      else
        modanns = Modann.all
      end
    end

    modanns
  end


  # get modanns (hash version)
  def get_hmodanns (annset_name, sourcedb, sourceid, serial = 0)
    modanns = get_modanns(annset_name, sourcedb, sourceid, serial)
    hmodanns = modanns.collect {|ma| ma.get_hash}
  end


  def save_hmodanns (hmodanns, annset, doc)
    hmodanns.each do |a|
      ma           = Modann.new
      ma.hid       = a[:id]
      ma.modtype   = a[:type]
      ma.modobj    = case a[:object]
        when /^R/
          #doc.subcatrels.find_by_annset_id_and_hid(annset.id, a[:object])
          doc.subinsrels.find_by_annset_id_and_hid(annset.id, a[:object])
        else
          doc.insanns.find_by_annset_id_and_hid(annset.id, a[:object])
      end
      ma.annset_id = annset.id
      ma.save
    end
  end


  def get_ascii_text(text)
    rewritetext = Utfrewrite.utf8_to_ascii(text)
    #rewritetext = text

    # escape non-ascii characters
    coder = HTMLEntities.new
    asciitext = coder.encode(rewritetext, :named)

    # restore back
    # greek letters
    asciitext.gsub!(/&[Aa]lpha;/, "alpha")
    asciitext.gsub!(/&[Bb]eta;/, "beta")
    asciitext.gsub!(/&[Gg]amma;/, "gamma")
    asciitext.gsub!(/&[Dd]elta;/, "delta")
    asciitext.gsub!(/&[Ee]psilon;/, "epsilon")
    asciitext.gsub!(/&[Zz]eta;/, "zeta")
    asciitext.gsub!(/&[Ee]ta;/, "eta")
    asciitext.gsub!(/&[Tt]heta;/, "theta")
    asciitext.gsub!(/&[Ii]ota;/, "iota")
    asciitext.gsub!(/&[Kk]appa;/, "kappa")
    asciitext.gsub!(/&[Ll]ambda;/, "lambda")
    asciitext.gsub!(/&[Mm]u;/, "mu")
    asciitext.gsub!(/&[Nn]u;/, "nu")
    asciitext.gsub!(/&[Xx]i;/, "xi")
    asciitext.gsub!(/&[Oo]micron;/, "omicron")
    asciitext.gsub!(/&[Pp]i;/, "pi")
    asciitext.gsub!(/&[Rr]ho;/, "rho")
    asciitext.gsub!(/&[Ss]igma;/, "sigma")
    asciitext.gsub!(/&[Tt]au;/, "tau")
    asciitext.gsub!(/&[Uu]psilon;/, "upsilon")
    asciitext.gsub!(/&[Pp]hi;/, "phi")
    asciitext.gsub!(/&[Cc]hi;/, "chi")
    asciitext.gsub!(/&[Pp]si;/, "psi")
    asciitext.gsub!(/&[Oo]mega;/, "omega")

    # symbols
    asciitext.gsub!(/&apos;/, "'")
    asciitext.gsub!(/&lt;/, "<")
    asciitext.gsub!(/&gt;/, ">")
    asciitext.gsub!(/&quot;/, '"')
    asciitext.gsub!(/&trade;/, '(TM)')
    asciitext.gsub!(/&rarr;/, ' to ')
    asciitext.gsub!(/&hellip;/, '...')

    # change escape characters
    asciitext.gsub!(/&([a-zA-Z]{1,10});/, '==\1==')
    asciitext.gsub!('==amp==', '&')

    asciitext
  end


  # to work on the hash representation of catanns
  # to assume that there is no bag representation to this method
  def realign_catanns (catanns, from_text, to_text)
    return nil if catanns == nil

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

    catanns_new = Array.new(catanns)

    (0...catanns.length).each do |i|
      catanns_new[i][:span][:begin] = position_map[catanns[i][:span][:begin]]
      catanns_new[i][:span][:end]   = position_map[catanns[i][:span][:end]]
    end

    catanns_new
  end

  def adjust_catanns (catanns, text)
    return nil if catanns == nil

    delimiter_characters = [
          " ",
          ".",
          "!",
          "?",
          ",",
          ":",
          ";",
          "+",
          "-",
          "/",
          "&",
          "(",
          ")",
          "{",
          "}",
          "[",
          "]",
          "\\",
          "\"",
          "'",
          "\n"
      ]

    catanns_new = Array.new(catanns)

    catanns_new.each do |c|
      while c[:span][:begin] > 0 and !delimiter_characters.include?(text[c[:span][:begin] - 1])
        c[:span][:begin] -= 1
      end

      while c[:span][:end] < text.length and !delimiter_characters.include?(text[c[:span][:end]])
        c[:span][:end] += 1
      end
    end

    catanns_new
  end


  def get_navigator ()
    navigator = []
    path = ''
    parts = request.fullpath.split('/')
    parts.each do |p|
      path += '/' + p
      navigator.push([p, path]);
    end
    navigator
  end

end