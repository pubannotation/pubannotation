# encoding: UTF-8
module ApplicationHelper
  # render image tag and title attribute for hint
  def hint_helper(options = {})
    image_tag("hint.png",
      :size => "16x16",
      :title => I18n.t("views.hints.#{options[:model]}.#{options[:column]}"))
  end

  def errors_helper(model)
    if model.errors.count > 0
      model_name = t("activerecord.models.#{model.class.to_s.downcase}")
      if model.errors.count == 1
        errors_header = t('errors.template.header.one', :model => model_name)
      else
        errors_header = t('errors.template.header.other', :model => model_name, :count => model.errors.count)
      end
      render :partial => 'shared/errors', :locals => {:model => model, :errors_header => errors_header }
    end
  end
  
  def language_switch_helper
    requested_path = url_for(:only_path => false, :overwrite_params => nil)
    en_text = 'English'
    if I18n.locale != :en
      en_text = link_to en_text, requested_path + '?locale=en'
    end
    ja_text = '日本語'
    if I18n.locale != :ja
      ja_text = link_to ja_text, requested_path + '?locale=ja'
    end
    "<ul><li>#{en_text}</li><li>#{ja_text}</li></ul>"
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
  
  def sanitize_sql(sql)
    # sanitized_sql = ActiveRecord::Base::sanitize(params[:sql])#.gsub('\'', '')
    sql.gsub("\"", '\'')
  end

  def sort_order(model)
    if params[:sort_key].present? && params[:sort_direction].present?
      sort_order = [[params[:sort_key], params[:sort_direction]]] 
    else
      sort_order = model::DefaultSortArray
    end
    # LOWER sort key column to ignore case
    sort_order.each_with_index do |sort_array, index|
      sort_key = sort_array[0]
      # Column names ignore case need to be listed in model::CaseInsensitiveArray
      sort_order[index][0] = lower_sort_key(model, sort_key)
    end
    return sort_order
  end

  def lower_sort_key(model, sort_key)
     if model::CaseInsensitiveArray.include?(sort_key)
       sort_key = "LOWER(#{sort_key})"
     end
     return sort_key
  end

  def sortable(model, sort_key, title = nil)
    if params[:controller] == 'home'
      # disable sorting 
      title
    else
      # enable sorting 
      title ||= sort_key
      sort_key = lower_sort_key(model, sort_key)
      sort_order = sort_order(model)
      current_direction = sort_order.assoc(sort_key)[1] if sort_order.present? && sort_order.assoc(sort_key).present?
      current_direction ||= 'DESC'
      css_class = "sortable-" + current_direction
      next_direction = current_direction == 'ASC' ? 'DESC' : 'ASC'

      if params[:search_projects]
        search_word = 'sort_direction'
        sort_params_in_url = request.fullpath.match(search_word)
        if sort_params_in_url.present?
          sort_params_string = '&' + search_word + sort_params_in_url.post_match
          current_path_without_sort_params = request.fullpath.gsub(sort_params_string, '')
        else
          current_path_without_sort_params = request.fullpath
        end
        link_to title, current_path_without_sort_params + '&' + {:sort_key => sort_key, :sort_direction => next_direction}.to_param, {:class => css_class}
      else
        link_to title, {:sort_key => sort_key, :sort_direction => next_direction}, {:class => css_class}
      end
    end
  end

  def get_project2 (project_name)
    authenticate_user!
    project = Project.find_by_name(project_name)
    raise ArgumentError, I18n.t('controllers.application.get_project.not_exist', :project_name => project_name) unless project.present?
    raise ArgumentError, I18n.t('controllers.application.get_project.private', :project_name => project_name) unless (project.accessibility == 1 || (user_signed_in? && project.user == current_user))
    project
  end

  def total_number(list, model = nil)
    if list.respond_to?(:total_entries)
      list.total_entries
    elsif list.respond_to?(:count)
      list.count
    else
      list.length if list.present?
    end
  end

  def gen_annotations (annotations, annserver, options = nil)
    response = if options && options[:method] == 'get'
      RestClient.get annserver, {:params => {:sourcedb => annotations[:sourcedb], :sourceid => annotations[:sourceid]}, :accept => :json}
    else
      RestClient.post annserver, {:text => annotations[:text]}.to_json, :content_type => :json, :accept => :json
    end

    raise IOError, "Bad gateway" unless response.code == 200

    result = JSON.parse response, :symbolize_names => true

    ann = {}

    ann[:text] = if result[:text].present?
      result[:text]
    else
      annotations[:text]
    end

    if result.respond_to?(:has_key?) && result.has_key?(:denotations)
      ann[:denotations] = result[:denotations]
      ann[:relations] = result[:relations] if defined? result[:relations]
      ann[:modifications] = result[:modifications] if defined? result[:modifications]
    elsif result.respond_to?(:first) && result.first.respond_to?(:has_key?) && result.first.has_key?(:obj)
      ann[:denotations] = result
    end

    ann
  end

end
