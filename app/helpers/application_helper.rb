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
    en_text = 'english'
    if I18n.locale != :en
      en_text = link_to en_text, requested_path + '?locale=en'
    end
    ja_text = '日本語'
    if I18n.locale != :ja
      ja_text = link_to ja_text, requested_path + '?locale=ja'
    end
    "[#{en_text} | #{ja_text}]"
  end
end
