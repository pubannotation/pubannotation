module ApplicationHelper
  # render image tag and title attribute for hint
  def hint_helper(options = {})
    image_tag("hint.png", 
      :size => "16x16", 
      :title => I18n.t("views.hint.#{options[:model]}.#{options[:column]}"))
  end
end
