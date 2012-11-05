require 'xml'

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
    if params[:pmdoc_id]
      texturi = "http://pubannotation/pmdocs/#{sourceid}"
    elsif params[:pmcdoc_id]
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
        parser = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        doc = parser.parse
        title    = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle').content
        abstract = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText').content

        doc = Doc.new
        doc.body = title + "\n" + abstract + "\n"
        doc.source = 'http://www.ncbi.nlm.nih.gov/pubmed/' + pmid
        doc.sourcedb = 'PubMed'
        doc.sourceid = pmid
        doc.serial = 0
        doc.section = 'TIAB'
        return doc
      else
        return nil
      end
    end
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


  # get simplified catanns
  def get_catanns_simple (annset_name, sourcedb, sourceid, serial = 0)
    catanns_s = []

  	catanns = get_catanns(annset_name, sourcedb, sourceid, serial)
    catanns_s = catanns.collect {|ca| Catann_s.new(ca)}

    catanns_s
  end

  class Catann_s
    attr_accessor :annset, :id, :span, :category
    def initialize (ca)
      @annset, @id, @span, @category = ca.annset.name, ca.hid, {:begin => ca.begin, :end => ca.end}, ca.category
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


#  class Catann_s
#    attr :annset_name, :doc_sourcedb, :doc_sourceid, :doc_serial, :hid, :begin, :end, :category
#    def initialize (ca)
#      @annset_name, @doc_sourcedb, @doc_sourceid, @doc_serial, @hid, @begin, @end, @category = ca.annset.name, ca.doc.sourcedb, ca.doc.sourceid, ca.doc.serial, ca.hid, ca.begin, ca.end, ca.category
#    end
#  end


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


  # get simplified catanns
  def get_insanns_simple (annset_name, sourcedb, sourceid, serial = 0)
    insanns_s = []

    insanns = get_insanns(annset_name, sourcedb, sourceid, serial)
    insanns_s = insanns.collect {|ia| Insann_s.new(ia)}

    insanns_s
  end

  class Insann_s
    attr :annset, :id, :type, :object
    def initialize (ia)
      @annset, @id, @type, @object = ia.annset.name, ia.hid, ia.instype, ia.insobj.hid
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


  # get simplified catanns
  def get_relanns_simple (annset_name, sourcedb, sourceid, serial = 0)
    relanns_s = []

    relanns = get_relanns(annset_name, sourcedb, sourceid, serial)
    relanns_s = relanns.collect {|ra| Relann_s.new(ra)}

    relanns_s
  end

  class Relann_s
    attr :annset, :id, :type, :subject, :object
    def initialize (ra)
      @annset, @id, @type, @subject, @object = ra.annset.name, ra.hid, ra.reltype, ra.relsub.hid, ra.relobj.hid
    end
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


  # get simplified catanns
  def get_modanns_simple (annset_name, sourcedb, sourceid, serial = 0)
    modanns_s = []

    modanns = get_modanns(annset_name, sourcedb, sourceid, serial)
    modanns_s = modanns.collect {|ma| Modann_s.new(ma)}

    modanns_s
  end

  class Modann_s
    attr :annset, :id, :type, :object
    def initialize (ma)
      @annset, @id, @type, @object = ma.annset.name, ma.hid, ma.modtype, ma.modobj.hid
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


  # annotation boundary adjustment
  def get_position_adjustment (from_text, to_text)
    position_map = Hash.new
    numchar, numdiff = 0, 0
    Diff::LCS.sdiff(from_text, to_text) do |h|
      position_map[h.old_position] = h.new_position
      numchar += 1
      numdiff += 1 if h.old_position != h.new_position
    end
     
    if (numdiff.to_f / numchar) > 0.5
      warn "text different too much: (#{numdiff.to_f/numchar})\n#{@doc.body}\n---\n#{params[:text]}"
    end
  end


  def adjust_catanns (catanns, from_text, to_text)
    position_map = Hash.new
    numchar, numdiff = 0, 0
    Diff::LCS.sdiff(from_text, to_text) do |h|
      position_map[h.old_position] = h.new_position
      numchar += 1
      numdiff += 1 if h.old_position != h.new_position
    end
     
    if (numdiff.to_f / numchar) > 0.5
      warn "text different too much: (#{numdiff.to_f/numchar})\n#{@doc.body}\n---\n#{params[:text]}"
    end

    new_catanns = Array.new
    catanns.each do |ca|
      new_catanns << ca
      span = new_catanns.last::span
      if span.respond_to?(:keys)
        span[:begin] = position_map[span[:begin]]
        span[:end]   = position_map[span[:end]]
      else
        span.each do |s|
          s[:begin] = position_map[s[:begin]]
          s[:end]   = position_map[s[:end]]
        end
      end
    end

    new_catanns
  end
