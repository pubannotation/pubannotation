module AnnotatorsHelper

	def annotator_options
		Annotator.accessibles(current_user).map{|a| [a[:name], a[:name]]}
	end

  def button_annotator_home
    # link_to t('activerecord.attributes.project.reference'), @project.reference, :class => 'home_button' if @project.reference.present?
    link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), @annotator.home, :class => 'home_button' if @annotator.home.present?
  end

  def badge_annotator_accessibility(annotator)
    annotator.is_public ?
			"<span class='badge' title='Public'><i class='fa fa-eye' aria-hidden='true'></i></span>" :
			""
  end

end
