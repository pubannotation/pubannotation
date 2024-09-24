module Recaptchable
  extend ActiveSupport::Concern

  included do
    helper_method :recaptcha_usable?
  end

  def recaptcha_usable?
    ENV['RECAPTCHA_SITE_KEY'].present? && ENV['RECAPTCHA_SECRET_KEY'].present?
  end
end
