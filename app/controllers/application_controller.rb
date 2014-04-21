# encoding: UTF-8
require 'pmcdoc'
require 'utfrewrite'
require 'sequence_alignment'

class ApplicationController < ActionController::Base
  include ApplicationHelper
  include AnnotationsHelper
  protect_from_forgery
  before_filter :set_locale
  after_filter :store_location
  
  def set_locale
    accept_locale = ['en', 'ja']
    if params[:locale].present? && accept_locale.include?(params[:locale])
      session[:locale] = params[:locale]
    end
    
    if session[:locale].blank?
      accept_language = request.env['HTTP_ACCEPT_LANGUAGE'] ||= 'en'
      locale_string = accept_language.scan(/^[a-z]{2}/).first
      if accept_locale.include?(locale_string.to_s)
        locale = locale_string
      else
        locale = :en
      end
      I18n.locale =  locale
    else
      I18n.locale = session[:locale]
    end
  end
  
  def store_location
    requested_path = url_for(:only_path => true)
    if requested_path != new_user_session_path && requested_path != new_user_registration_path && request.method == 'GET'
      session[:after_sign_in_path] = request.fullpath
    end
  end
  
  def after_sign_in_path_for(resource)
    session[:after_sign_in_path] ||= root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    request.referrer
  end

  def get_docspec(params)
    sourcedb = params[:sourcedb]
    sourceid = params[:sourceid]
    serial   = params[:div_id].present? ? params[:div_id] : 0
    id = params[:id] if params[:id]

    return sourcedb, sourceid, serial, id
  end


  def get_project (project_name)
    project = Project.find_by_name(project_name)
    if project
      if (project.accessibility == 1 or (user_signed_in? and project.user == current_user))
        return project, nil
      else
        return nil, I18n.t('controllers.application.get_project.private', :project_name => project_name)
      end
    else
      return nil, I18n.t('controllers.application.get_project.not_exist', :project_name => project_name)
    end
  end


  def get_projects (options = {})
    projects = (options.present? && options[:doc].present?)? options[:doc].projects : Project.where('id > ?', 0)
    # TODO associate projects should be got ?
    projects.sort!{|x, y| x.name <=> y.name}
    projects = projects.keep_if{|a| a.accessibility == 1 or (user_signed_in? and a.user == current_user)}
  end


  def get_doc (sourcedb, sourceid, serial = 0, project = nil, id = nil)
    if id
      doc = Doc.find(id)
    else
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    end

    if doc
      if project
        if !doc.projects.include?(project)
          doc = nil
          notice = I18n.t('controllers.application.get_doc.not_belong_to', :sourcedb => sourcedb, :sourceid => sourceid, :project_name => project.name)
        end
      end
    else
      notice = I18n.t('controllers.application.get_doc.no_annotation', :sourcedb => sourcedb, :sourceid => sourceid) 
    end

    return doc, notice
  end


  def get_divs (sourceid, project = nil)
    divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', sourceid)
    if divs and !divs.empty?
      if project and !divs.first.projects.include?(project)
        divs = nil
        notice = I18n.t('controllers.application.get_divs.not_belong_to', :sourceid => sourceid, :project_name => project.name)
      end
    else
      divs = nil
      notice = I18n.t('controllers.application.get_divs.no_annotation', :sourceid => sourceid) 
    end

    return [divs, notice]
  end


  def rewrite_ascii (docs)
    docs.each do |doc|
      doc.body = get_ascii_text(doc.body)
    end
    docs
  end

  def archive_texts (docs)
    unless docs.empty?
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


  def archive_annotation (project_name, format = 'json')
    project = Project.find_by_name(project_name)
    project.docs.each do |d|
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


  def gen_annotations (annotations, annserver)
    RestClient.post annserver, {:text => annotations[:text], :options => {}.to_json}, :content_type => :json, :accept => :json do |response, request, result|
      case response.code
      when 200
        denotations = JSON.parse response, :symbolize_names => true
        annotations[:denotations] = denotations
        annotations
      else
        nil
      end
    end
  end


  def save_annotations (annotations, project, doc)
    denotations_old = doc.denotations.where(:project_id => project.id)
    denotations_old.destroy_all
    notice = I18n.t('controllers.application.save_annotations.annotation_cleared')

    if annotations[:denotations] and !annotations[:denotations].empty?
      denotations, notice = clean_hdenotations(annotations[:denotations])
      denotations = realign_denotations(denotations, annotations[:text], doc.body)
      save_hdenotations(denotations, project, doc)

      if annotations[:relations] and !annotations[:relations].empty?
        relations = annotations[:relations]
        relations = relations.values if relations.respond_to?(:values)
        save_hrelations(relations, project, doc)
      end

      if annotations[:modifications] and !annotations[:modifications].empty?
        modifications = annotations[:modifications]
        modifications = modifications.values if modifications.respond_to?(:values)
        save_hmodifications(modifications, project, doc)
      end

      notice = I18n.t('controllers.application.save_annotations.successfully_saved')
    end
  end


  ## get denotations
  def get_denotations (project_name, sourcedb, sourceid, serial = 0)
    denotations = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if project_name and project = doc.projects.find_by_name(project_name)
        denotations = doc.denotations.where("project_id = ?", project.id).order('begin ASC')
      else
        denotations = doc.denotations
      end
    else
      if project_name and project = Project.find_by_name(project_name)
        denotations = project.denotations
      else
        denotations = Denotation.all
      end
    end

    denotations
  end


  # get denotations (hash version)
  def get_hdenotations (project_name, sourcedb, sourceid, serial = 0)
    denotations = get_denotations(project_name, sourcedb, sourceid, serial)
    hdenotations = denotations.collect {|ca| ca.get_hash}
    hdenotations
  end


  # clean denotations
  def clean_hdenotations (denotations)
    ids = denotations.collect {|d| d[:id]}
    ids.compact!

    idnum = 1
    denotations.each do |a|
      return nil, "format error" unless (a[:span] or (a[:begin] and a[:end])) and a[:obj]

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

    [denotations, nil]
  end


  def save_hdenotations (hdenotations, project, doc)
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


  def chain_denotations (denotations_s)
    # This method is not called anywhere.
    # And just returns denotations_s array.
    mid = 0
    denotations_s.each do |ca|
      if (cid = ca.hid[1..-1].to_i) > mid 
        mid = cid
      end
    end
  end


  ## get relations
  def get_relations (project_name, sourcedb, sourceid, serial = 0)
    relations = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if project_name and project = doc.projects.find_by_name(project_name)
        relations  = doc.subcatrels.where("relations.project_id = ?", project.id)
        relations += doc.subinsrels.where("relations.project_id = ?", project.id)
        relations.sort! {|r1, r2| r1.hid[1..-1].to_i <=> r2.hid[1..-1].to_i}
      else
        relations = doc.subcatrels + doc.subinsrels unless doc.denotations.empty?
      end
    else
      if project_name and project = Project.find_by_name(project_name)
        relations = project.relations
      else
        relations = Relation.all
      end
    end

    relations
  end


  # get relations (hash version)
  def get_hrelations (project_name, sourcedb, sourceid, serial = 0)
    relations = get_relations(project_name, sourcedb, sourceid, serial)
    hrelations = relations.collect {|ra| ra.get_hash}
  end


  def save_hrelations (hrelations, project, doc)
    hrelations.each do |a|
      ra           = Relation.new
      ra.hid       = a[:id]
      ra.pred      = a[:pred]
      ra.subj      = case a[:subj]
        when /^[TE]/ then Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, project.id, a[:subj])
        else           doc.instances.find_by_project_id_and_hid(project.id, a[:subj])
      end
      ra.obj       = case a[:obj]
        when /^[TE]/ then Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, project.id, a[:obj])
        else           doc.instances.find_by_project_id_and_hid(project.id, a[:obj])
      end
      ra.project_id = project.id
      ra.save
    end
  end


  ## get modifications
  def get_modifications (project_name, sourcedb, sourceid, serial = 0)
    modifications = []

    if sourcedb and sourceid and doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if project_name and project = doc.projects.find_by_name(project_name)
        modifications = doc.subcatrelmods.where("modifications.project_id = ?", project.id)
        modifications.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      else
        #modifications = doc.modifications unless doc.denotations.empty?
        modifications = doc.subcatrelmods
        modifications.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      end
    else
      if project_name and project = Project.find_by_name(project_name)
        modifications = project.modifications
      else
        modifications = Modification.all
      end
    end

    modifications
  end


  # get modifications (hash version)
  def get_hmodifications (project_name, sourcedb, sourceid, serial = 0)
    modifications = get_modifications(project_name, sourcedb, sourceid, serial)
    hmodifications = modifications.collect {|ma| ma.get_hash}
  end


  def save_hmodifications (hmodifications, project, doc)
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

  # to work on the hash representation of denotations
  # to assume that there is no bag representation to this method
  def realign_denotations (denotations, from_text, to_text)
    return nil if denotations == nil

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

    denotations_new = Array.new(denotations)

    (0...denotations.length).each do |i|
      denotations_new[i][:span][:begin] = position_map[denotations[i][:span][:begin]]
      denotations_new[i][:span][:end]   = position_map[denotations[i][:span][:end]]
    end

    denotations_new
  end

  def adjust_denotations (denotations, text)
    return nil if denotations == nil

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

    denotations_new = Array.new(denotations)

    denotations_new.each do |c|
      while c[:span][:begin] > 0 and !delimiter_characters.include?(text[c[:span][:begin] - 1])
        c[:span][:begin] -= 1
      end

      while c[:span][:end] < text.length and !delimiter_characters.include?(text[c[:span][:end]])
        c[:span][:end] += 1
      end
    end

    denotations_new
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
  
  def render_status_error(status)
    # translation required for each httpstatus eg: errors.statuses.forbidden
    flash[:error] = t("errors.statuses.#{status}")
    render 'shared/status_error', :status => status
  end
end