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


  ## get doctext
  def get_doctext (sourcedb, sourceid, serial = 0)
    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) #if sourcedb and sourceid
    doc.body if doc
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
        catanns = doc.catanns.where("annset_id = ?", annset.id)
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
    attr :annset_name, :hid, :begin, :end, :category
    def initialize (ca)
      @annset_name, @hid, @begin, @end, @category = ca.annset.name, ca.hid, ca.begin, ca.end, ca.category
    end
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
    attr :annset_name, :hid, :instype, :insobj_hid
    def initialize (ia)
      @annset_name, @hid, @instype, @insobj_hid = ia.annset.name, ia.hid, ia.instype, ia.insobj.hid
    end
  end


  ## get relanns
  def get_relanns (annset_name, sourcedb, sourceid, serial = 0)
    relanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        relanns  = doc.subcatrels.where("relanns.annset_id = ?", annset.id)
        relanns += doc.subinsrels.where("relanns.annset_id = ?", annset.id)
#        relanns += doc.objcatrels.where("relanns.annset_id = ?", annset.id)
#        relanns += doc.objinsrels.where("relanns.annset_id = ?", annset.id)
      else
        relanns = doc.relanns unless doc.catanns.empty?
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
    attr :annset_name, :hid, :relsub_hid, :reltype, :relobj_hid
    def initialize (ra)
      @annset_name, @hid, @relsub_hid, @reltype, @relobj_hid = ra.annset.name, ra.hid, ra.relsub.hid, ra.reltype, ra.relobj.hid
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
      else
        modanns = doc.modanns unless doc.catanns.empty?
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
    attr :annset_name, :hid, :modtype, :modobj_hid
    def initialize (ma)
      @annset_name, @hid, @modtype, @modobj_hid = ma.annset.name, ma.hid, ma.modtype, ma.modobj.hid
    end
  end
