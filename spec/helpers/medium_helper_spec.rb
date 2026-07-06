# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumHelper, type: :helper do
  describe '#medium_tag' do
    let(:user) { create(:user) }

    def attach_file(medium, filename, content_type)
      medium.file.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', filename)),
        filename:,
        content_type:
      )
      medium.save!
      medium
    end

    def parsed_tag(html)
      Nokogiri::HTML::DocumentFragment.parse(html).children.first
    end

    context 'when no file is attached' do
      it 'returns nil' do
        medium = build(:medium, user:)
        expect(helper.medium_tag(medium)).to be_nil
      end
    end

    context 'when a file is attached' do
      it 'renders an img tag capped to the viewport height for an image medium' do
        medium = attach_file(build(:medium, user:, media_type: :image, content_type: 'image/png'), 'test_image.png', 'image/png')

        node = parsed_tag(helper.medium_tag(medium))

        expect(node.name).to eq('img')
        expect(node['style']).to include('max-height: 80vh')
      end

      it 'renders a video tag with controls capped to the viewport height for a video medium' do
        medium = attach_file(build(:medium, user:, media_type: :video, content_type: 'video/mp4'), 'test_video.mp4', 'video/mp4')

        node = parsed_tag(helper.medium_tag(medium))

        expect(node.name).to eq('video')
        expect(node['controls']).to eq('controls')
        expect(node['style']).to include('max-height: 80vh')
      end

      it 'renders an audio tag with controls for an audio medium' do
        medium = attach_file(build(:medium, user:, media_type: :audio, content_type: 'audio/mpeg'), 'test_audio.mp3', 'audio/mpeg')

        node = parsed_tag(helper.medium_tag(medium))

        expect(node.name).to eq('audio')
        expect(node['controls']).to eq('controls')
      end
    end
  end
end
