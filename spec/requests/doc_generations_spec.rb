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
    context 'when logged in' do
      before { sign_in user }

      it 'renders the form' do
        get new_project_doc_generation_path(project.name)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get new_project_doc_generation_path(project.name)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }
      let(:restricted_project) { create(:project, user: restricted_user) }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        get new_project_doc_generation_path(restricted_project.name)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the project does not exist' do
      before { sign_in user }

      it 'redirects to home' do
        get new_project_doc_generation_path('nonexistent-project')
        expect(response).to redirect_to(home_path)
      end
    end
  end

  describe 'POST /projects/:project_id/doc_generations' do
    context 'when logged in' do
      before { sign_in user }

      it 'uses the generated caption as the body and links the medium' do
        allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))

        post project_doc_generations_path(project.name),
             params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid }, sourcedb: 'Example', sourceid: '001' }

        expect(response).to redirect_to(show_project_sourcedb_sourceid_docs_path(project.name, "Example@#{user.username}", '001'))
        doc = Doc.last
        expect(doc.body).to eq('A generated caption.')
        expect(doc.sourcedb).to eq("Example@#{user.username}")
        expect(doc.sourceid).to eq('001')
        expect(doc.medium).to eq(image_medium)
      end

      it 'returns an error when no media is specified' do
        expect {
          post project_doc_generations_path(project.name), params: {}
        }.not_to change(Doc, :count)

        expect(response).to redirect_to(new_project_doc_generation_path(project.name))
      end

      it 'returns an error when only the media sourcedb is specified' do
        expect {
          post project_doc_generations_path(project.name),
               params: { media: { sourcedb: image_medium.sourcedb, sourceid: '' } }
        }.not_to change(Doc, :count)

        expect(response).to redirect_to(new_project_doc_generation_path(project.name))
      end

      it 'returns an error when only the media sourceid is specified' do
        expect {
          post project_doc_generations_path(project.name),
               params: { media: { sourcedb: '', sourceid: image_medium.sourceid } }
        }.not_to change(Doc, :count)

        expect(response).to redirect_to(new_project_doc_generation_path(project.name))
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

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }
      let(:restricted_project) { create(:project, user: restricted_user) }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        expect {
          post project_doc_generations_path(restricted_project.name),
               params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid } }
        }.not_to change(Doc, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post project_doc_generations_path(project.name),
             params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when the project does not exist' do
      before { sign_in user }

      it 'redirects to home for HTML requests' do
        post project_doc_generations_path('nonexistent-project'),
             params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid } }
        expect(response).to redirect_to(home_path)
      end

      it 'returns an error for JSON requests' do
        post project_doc_generations_path('nonexistent-project', format: :json),
             params: { media: { sourcedb: image_medium.sourcedb, sourceid: image_medium.sourceid } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
