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
    "#{en_text} #{ja_text}"
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
end
