require 'xml'
require 'pmcdoc'

class ApplicationController < ActionController::Base
  protect_from_forgery

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

  ## get docuri
  def get_docuri (sourcedb, sourceid)
    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, 0)
    doc.source if doc
  end


  ## get doctext
  def get_doctext (sourcedb, sourceid, serial = 0)
    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    doc.body if doc
  end


  ## get texturi
  def get_texturi (sourcedb, sourceid, serial = 0)
    if sourcedb == 'PubMed'
      texturi = "http://pubannotation/pmdocs/#{sourceid}"
    elsif sourcedb == 'PMC'
      texturi = "http://pubannotation/pmcdocs/#{sourceid}/divs/#{serial}"
    else
      texturi = nil
    end
    texturi
  end


  ## get a pmdoc from pubmed
  def get_pmdoc (pmid)
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
  def get_pmcdoc (pmcid)
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


  def archive_annotation (annset_name, format = 'json')
    annset = Annset.find_by_name(annset_name)
    annset.docs.each do |d|
    end
  end


  def get_conversion (data, converter, identifier = nil)
    RestClient.post converter, {:data => data, :identifier => identifier}, :content_type => 'multipart/form-data' do |response, request, result|
      case response.code
      when 200
        response
      else
        nil
      end
    end
  end


  def find_annsets (doc = nil)
    annsets = (doc)? doc.annsets : Annset.all
    annsets.sort!{|x, y| x.name <=> y.name}
    annsets = annsets.keep_if{|a| a.accessibility == 1 or (user_signed_in? and a.user == current_user)}
  end


  def find_annset (annset_name)
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


  def find_doc (sourcedb, sourceid, serial, annset = nil)
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


  def find_pmdoc (sourceid, annset = nil)
    doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
    if doc
      if annset and !doc.annsets.include?(annset)
        doc = nil
        notice = "The document, PubMed:#{sourceid}, does not belong to the annotation set, #{annset.name}."
      end
    else
      notice = "No annotation to the document, PubMed:#{sourceid}, exists in PubAnnotation." 
    end

    return doc, notice
  end


  def find_pmcdoc (sourceid, annset = nil)
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


  def find_or_add_pmdoc (sourceid, annset = nil)
    if annset
      if user_signed_in? and annset.user = current_user
        doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
        if doc
          unless doc.annsets.include?(annset)
            annset.docs << doc
            notice = "The document, PubMed:#{sourceid}, was added to the annotation set, #{annset.name}."
          end
        else
          doc = get_pmdoc(sourceid)
          if doc
            annset.docs << doc
            notice = "The document, PubMed:#{sourceid}, was created and added to the annotation set, #{params[:annset_id]}."
          else
            notice = "The document, PubMed:#{sourceid}, could not be created." 
          end
        end
      else
        notice = "Only the creator of the annotation set can add or delete documents to or from an annotation set."
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
      unless doc
        doc = get_pmdoc(pmid)
        if doc
          notice = "The document, PubMed:#{sourceid}, was created in PubAnnotation." 
        else
          notice = "The document, PubMed:#{sourceid}, could not be created." 
        end
      end
    end

    return doc, notice
  end


  def find_or_get_pmcdoc (sourceid, annset = nil)
    divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', sourceid)
    if annset
      if divs and !divs.empty?
        unless divs.first.annsets.include?(annset)
          divs.each {|div| annset.docs << div}
          notice = "The document, PMC::#{sourceid}, was added to the annotation set, #{annset.name}."
        end
      else
        divs = get_pmcdoc(sourceid)
        if divs
          divs.each {|div| annset.docs << div}
          notice = "The document, PMC:#{sourceid}, was created and added to the annotation set, #{annset.name}."
        else
          notice = "The document, PMC:#{sourceid}, is not in the annotation set, #{annset.name}."
        end
      end
    else
      unless divs
        divs = get_pmcdoc(sourceid)
        if divs
          notice = "The document, PMC:#{sourceid}, was created in PubAnnotation." 
        else
          notice = "The document, PMC:#{sourceid}, could not be created." 
        end
      end
    end

    return [divs, notice]
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

    catanns.each do |a|
      return nil, "format error" unless a[:id] and a[:span] and a[:span][:begin] and a[:span][:end] and a[:category]
      a[:span][:begin] = a[:span][:begin].to_i
      a[:span][:end]   = a[:span][:end].to_i
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
    # escape non-ascii characters
    coder = HTMLEntities.new
    asciitext = coder.encode(text, :named)

    # restore back
    asciitext.gsub!('&apos;', "'")

    # change escape characters
    asciitext.gsub!(/&([a-zA-Z]{1,10});/, '==\1==')

    asciitext
  end


  # to work on the hash representation of catanns
  # to assume that there is no bag representation to this method
  def adjust_catanns (catanns, from_text, to_text)
    position_map = Hash.new
    numchar, numdiff = 0, 0
    Diff::LCS.sdiff(from_text, to_text) do |h|
      position_map[h.old_position] = h.new_position
      numchar += 1
      numdiff += 1 if h.old_position != h.new_position
    end

    # TODO
    # if (numdiff.to_f / numchar) > 2
    #   return nil, "The text is too much different from PubMed. The mapping could not be calculated.: #{numdiff}/#{numchar}"
    # else

    catanns_new = Array.new(catanns)

    (0...catanns.length).each do |i|
      catanns_new[i][:span][:begin] = position_map[catanns[i][:span][:begin]]
      catanns_new[i][:span][:end]   = position_map[catanns[i][:span][:end]]
    end

    [catanns_new, nil]
  end

end