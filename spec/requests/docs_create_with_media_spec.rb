# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /docs.json', type: :request do
  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  let(:password) { 'password' }
  let(:user) do
    create(:user, password: password).tap(&:confirm)
  end
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium) }

  let(:headers) do
    {
      'HTTP_AUTHORIZATION' =>
        ActionController::HttpAuthentication::Basic.encode_credentials(
          user.email,
          password
        )
    }
  end

  let(:params) do
    {
      project_id: project.name,
      doc: {
        text: 'doctor findings',
        sourcedb: 'Example',
        sourceid: '001'
      },
      commit: 'Create'
    }
  end

  it 'creates a doc linked to the specified medium' do
    post '/docs.json',
         params: params.merge(
           media: {
             sourcedb: medium.sourcedb,
             sourceid: medium.sourceid
           }
         ),
         headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to eq(medium)
  end

  it 'creates a doc without a medium when media is omitted' do
    post '/docs.json', params: params, headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to be_nil
  end

  it 'returns an error when the specified medium does not exist' do
    post '/docs.json',
         params: params.merge(
           media: {
             sourcedb: 'NonExistentDB',
             sourceid: 'nonexistent-001'
           }
         ),
         headers: headers

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'creates a doc without a medium when media fields are left blank' do
    post '/docs.json',
         params: params.merge(media: { sourcedb: '', sourceid: '' }),
         headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to be_nil
  end

  context 'when generate_text_from_media is requested' do
    let(:image_medium) do
      medium = create(:medium)
      medium.file.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
        filename: 'test_image.png',
        content_type: 'image/png'
      )
      medium
    end

    it 'uses the generated caption as the body and keeps the given sourcedb/sourceid' do
      allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))

      post '/docs.json',
           params: params.merge(
             media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid },
             generate_text_from_media: '1'
           ),
           headers: headers

      expect(response).to have_http_status(:created)
      doc = Doc.last
      expect(doc.body).to eq('A generated caption.')
      # Personalized as "<given sourcedb>@<username>" by Doc.hdoc_normalize!.
      # If hdoc[:sourcedb] were lost (the bug this guards against), this
      # would come back as just "@#{user.username}" instead.
      expect(doc.sourcedb).to eq("#{params[:doc][:sourcedb]}@#{user.username}")
      expect(doc.sourceid).to eq(params[:doc][:sourceid])
      expect(doc.medium).to eq(image_medium)
    end

    it 'returns an error when the medium is not an image' do
      video_medium = create(:medium, media_type: :video, content_type: 'video/mp4')
      video_medium.file.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
        filename: 'test_video.mp4',
        content_type: 'video/mp4'
      )

      post '/docs.json',
           params: params.merge(
             media: { sourcedb: video_medium.sourcedb, sourceid: video_medium.sourceid },
             generate_text_from_media: '1'
           ),
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns an error when the medium has no attached file' do
      medium_without_file = create(:medium)

      post '/docs.json',
           params: params.merge(
             media: { sourcedb: medium_without_file.sourcedb, sourceid: medium_without_file.sourceid },
             generate_text_from_media: '1'
           ),
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
