class TextaeAnnotation < ApplicationRecord
  before_create :clean_old_annotations

  scope :older_than_one_day, -> { where("created_at < ?", 1.day.ago) }

  def self.generate_textae_html(annotation)
    html = <<~HTML
      <!DOCTYPE HTML>
      <html>

      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <link rel="stylesheet" href="https://textae.pubannotation.org/lib/css/textae-13.6.1.min.css">
        <script src="https://textae.pubannotation.org/lib/textae-13.6.1.min.js"></script>
      </head>

      <body>
        <div class="textae-editor" mode="edit">
          #{annotation}
        </div>
      </body>

      </html>
    HTML

    html
  end

  private

  def clean_old_annotations
    TextaeAnnotation.older_than_one_day.destroy_all
  end
end
