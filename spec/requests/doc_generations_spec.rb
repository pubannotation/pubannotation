# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DocGenerationsController', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:project) { create(:project, user: user) }
  let(:image_medium) do
    medium = create(:medium)
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
      filename: 'test_image.png',
      content_type: 'image/png'
    )
    medium
  end

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  describe 'GET /projects/:project_id/doc_generations/new' do
    it 'renders the form' do
      sign_in user
      get new_project_doc_generation_path(project.name)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /projects/:project_id/doc_generations' do
    before { sign_in user }

    it 'uses the generated caption as the body and links the medium' do
      allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))

      post project_doc_generations_path(project.name),
           params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid }, sourcedb: 'Example', sourceid: '001' }

      expect(response).to redirect_to(show_project_sourcedb_sourceid_docs_path(project.name, "Example@#{user.username}", '001'))
      doc = Doc.last
      expect(doc.body).to eq('A generated caption.')
      expect(doc.medium).to eq(image_medium)
    end

    it 'returns an error when the specified medium does not exist' do
      expect {
        post project_doc_generations_path(project.name),
             params: { media: { sourcedb: 'NonExistentDB', sourceid: 'nonexistent-001' } }
      }.not_to change(Doc, :count)

      expect(response).to redirect_to(new_project_doc_generation_path(project.name))
    end

    it 'returns an error when the medium is not an image' do
      video_medium = create(:medium, media_type: :video, content_type: 'video/mp4')

      expect {
        post project_doc_generations_path(project.name),
             params: { media: { sourcedb: video_medium.sourcedb, sourceid: video_medium.sourceid } }
      }.not_to change(Doc, :count)

      expect(response).to redirect_to(new_project_doc_generation_path(project.name))
    end

    it 'returns an error when the medium has no attached file' do
      medium_without_file = create(:medium)

      expect {
        post project_doc_generations_path(project.name),
             params: { media: { sourcedb: medium_without_file.sourcedb, sourceid: medium_without_file.sourceid } }
      }.not_to change(Doc, :count)

      expect(response).to redirect_to(new_project_doc_generation_path(project.name))
    end
  end
end
