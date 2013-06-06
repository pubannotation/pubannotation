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
end
