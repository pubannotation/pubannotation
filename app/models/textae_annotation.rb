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
        <script>
        // Run scripts before start the textae.
        !function(){
          var userAgent = window.navigator.userAgent.toLowerCase()
          var isIE = (userAgent.indexOf('msie') >= 0 || userAgent.indexOf('trident') >= 0)
          if (isIE) alert('Microsoft IE is not supported. Please use a HTML5-conformant browser, e.g., FireFox, Chrome, or Safari.')

          if (location.search) {
            const queries = location.search.substring(1).split('&')
            const editors = Array.from(document.querySelectorAll('.textae-editor'))

            editors.forEach(function (editor) {
              queries.forEach(function (query) {
                var name = query.split('=')[0]
                editor.setAttribute(name, query.split('=')[1] ? decodeURIComponent(query.split('=')[1]) : name)
              })
            })
          }
        }()

        // Run scripts after start the textae.
        window.addEventListener('load', () => document.querySelector('.textae-editor').focus())
        </script>
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
