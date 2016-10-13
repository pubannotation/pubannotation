# encoding: UTF-8
require 'pmcdoc'
require 'utfrewrite'
require 'text_alignment'

class ApplicationController < ActionController::Base
  include ApplicationHelper
  include AnnotationsHelper
  protect_from_forgery
  before_filter :set_locale
  after_filter :store_location

  def is_root_user?
    unless root_user?
      render_status_error(:unauthorized)
    end
  end
  
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
    if requested_path != new_user_session_path && requested_path != new_user_registration_path && (requested_path =~ /password/).blank?  && request.method == 'GET'
      session[:after_sign_in_path] = request.fullpath
    end
  end

  def http_basic_authenticate 
    authenticate_or_request_with_http_basic do |username, password|
      user = User.find_by_email(username)
      if user.present? && user.valid_password?(password)
        sign_in :user, user 
      else
        respond_to do |format|
          format.json{
            res = {
              status: :unauthorized,
              message: 'Authentication Failed'
            }
            render json: res.to_json
          }
        end
      end
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

    serial =  if params[:divid].present?
                params[:divid]
              elsif Doc.has_divs?(sourcedb, sourceid)
                Doc.get_div_ids(sourcedb, sourceid)
              else
                0
              end
    id = params[:id] if params[:id]

    return sourcedb, sourceid, serial, id
  end

  # to be deprecated in favor for get_project2
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

  def get_project2 (project_name)
    project = Project.find_by_name(project_name)
    raise ArgumentError, I18n.t('controllers.application.get_project.not_exist', :project_name => project_name) unless project.present?
    raise ArgumentError, I18n.t('controllers.application.get_project.private', :project_name => project_name) unless (project.accessibility == 1 || (user_signed_in? && project.user == current_user))
    project
  end

  def get_projects (options = {})
    projects = (options.present? && options[:doc].present?)? options[:doc].projects : Project.where('id > ?', 0)
    # TODO associate projects should be got ?
    projects.sort!{|x, y| x.name <=> y.name}
    projects = projects.keep_if{|a| a.accessibility == 1 or (user_signed_in? and a.user == current_user)}
  end


  def get_doc (sourcedb, sourceid, serial = 0, project = nil, id = nil)
    doc = if id
      Doc.find(id)
    else
      Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    end

    if doc
      if project
        projects = project.respond_to?(:each) ? project : [project]
        if (doc.projects & projects).empty?
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
        relations.sort! {|r1, r2| r1.hid[1..-1].to_i <=> r2.hid[1..-1].to_i}
      else
        relations = doc.subcatrels unless doc.denotations.empty?
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

  def get_docs_projects
    sort_order = sort_order(Project)
    @projects = @doc.projects.accessible(current_user).order(sort_order)
    if params[:projects].present?
      select_project_names = params[:projects].split(',').uniq
      @selected_projects = Array.new 
      select_project_names.each do |project_name|
        @selected_projects.push @projects.detect{|project| project.name == project_name}
      end
      @projects -= @selected_projects
    end
  end
end
