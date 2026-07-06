module MediumHelper
  def current_user_owns_medium?(medium)
    medium.user == current_user
  end

  def medium_tag(medium, **options)
    return unless medium.file.attached?

    url = url_for(medium.file)
    # max-height keeps portrait video/images from filling the whole viewport.
    style = 'max-width: 100%; max-height: 80vh'
    case medium.media_type
    when 'image' then image_tag(url, style:, **options)
    when 'video' then video_tag(url, controls: true, style:, **options)
    when 'audio' then audio_tag(url, controls: true, **options)
    end
  end
end
