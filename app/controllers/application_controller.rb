class ApplicationController < ActionController::Base
  protect_from_forgery

  ## get doctext
  def get_doctext (sourcedb, sourceid)
    doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid) #if sourcedb and sourceid
    doc.body if doc
  end

  ## get catanns
  def get_catanns (sourcedb, sourceid, annset_name)
    catanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
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
  def get_catanns_simple (sourcedb, sourceid, annset_name)
    catanns_s = []

  	catanns = get_catanns(sourcedb, sourceid, annset_name)
    catanns_s = catanns.collect {|ca| Catann_s.new(ca)}

    catanns_s
  end

  class Catann_s
    attr :annset_name, :sourcedb, :sourceid, :hid, :begin, :end, :category
    def initialize (ca)
      @annset_name, @sourcedb, @sourceid, @hid, @begin, @end, @category = ca.annset.name, ca.doc.sourcedb, ca.doc.sourceid, ca.hid, ca.begin, ca.end, ca.category
    end
  end


  ## get insanns
  def get_insanns (sourcedb, sourceid, annset_name)
    insanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
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
  def get_insanns_simple (sourcedb, sourceid, annset_name)
    insanns_s = []

    insanns = get_insanns(sourcedb, sourceid, annset_name)
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
  def get_relanns (sourcedb, sourceid, annset_name)
    relanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        relanns = doc.relanns.where("relanns.annset_id = ?", annset.id)
      else
        relanns = doc.relanns
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
  def get_relanns_simple (sourcedb, sourceid, annset_name)
    relanns_s = []

    relanns = get_relanns(sourcedb, sourceid, annset_name)
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
  def get_modanns (sourcedb, sourceid, annset_name)
    modanns = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
      p doc
      puts "-----"
      if annset_name and annset = doc.annsets.find_by_name(annset_name)
        modanns = doc.modanns.where("modanns.annset_id = ?", annset.id)
      else
        modanns = doc.modanns
        p modanns
        puts "-----"
        p doc.insanns
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
  def get_modanns_simple (sourcedb, sourceid, annset_name)
    modanns_s = []

    modanns = get_modanns(sourcedb, sourceid, annset_name)
    modanns_s = modanns.collect {|ma| Modann_s.new(ma)}

    modanns_s
  end

  class Modann_s
    attr :annset_name, :hid, :modtype, :modobj_hid
    def initialize (ma)
      @annset_name, @hid, @modtype, @modobj_hid = ma.annset.name, ma.hid, ma.modtype, ma.modobj.hid
    end
  end
