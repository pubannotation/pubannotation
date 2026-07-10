# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MediaController', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:image_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec', 'fixtures', 'files', 'test_image.png'),
      'image/png'
    )
  end

  describe 'GET /media/jobs' do
    context 'when logged in' do
      before { sign_in user }

      it 'renders the jobs list' do
        get jobs_media_path
        expect(response).to have_http_status(:ok)
      end

      it 'renders the jobs list when a job has messages' do
        job = create(:job, organization: user)
        job.add_message(sourcedb: 'PMC', sourceid: '1', body: 'something went wrong')

        get jobs_media_path

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get jobs_media_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /media/jobs/latest_jobs_table' do
    context 'when logged in' do
      before { sign_in user }

      it 'renders the jobs table partial' do
        get jobs_latest_jobs_table_media_path
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get jobs_latest_jobs_table_media_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /media' do
    let!(:medium) { create(:medium) }

    context 'when logged in' do
      it 'renders the index' do
        sign_in user
        get media_path
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get media_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /media/sourcedbs/:sourcedb/sourceids/:sourceid' do
    let(:medium) { create(:medium) }

    context 'when logged in' do
      it 'renders the show page' do
        sign_in user
        get show_media_path(sourcedb: medium.sourcedb, sourceid: medium.sourceid)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get show_media_path(sourcedb: medium.sourcedb, sourceid: medium.sourceid)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /media/new' do
    context 'when logged in' do
      before { sign_in user }

      it 'renders the upload form' do
        get new_medium_path
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get new_medium_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /media' do
    context 'when logged in' do
      before { sign_in user }

      it 'creates a medium with valid params' do
        expect {
          post media_path, params: {
            medium: {
              sourcedb: 'TestDB',
              sourceid: 'img-001',
              media_type: 'image',
              file: image_file
            }
          }
        }.to change(Medium, :count).by(1)
        expect(response).to redirect_to(new_medium_path)
      end

      it 'renders new with invalid params' do
        post media_path, params: {
          medium: {
            sourcedb: '',
            sourceid: 'img-001',
            media_type: 'image'
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post media_path, params: {
          medium: { sourcedb: 'TestDB', sourceid: 'img-001', media_type: 'image' }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE /media/sourcedbs/:sourcedb/sourceids/:sourceid' do
    let(:medium) { create(:medium, user: user) }

    context 'when logged in as the creator' do
      before { sign_in user }

      it 'deletes the medium' do
        medium
        expect {
          delete destroy_media_path(sourcedb: medium.sourcedb, sourceid: medium.sourceid)
        }.to change(Medium, :count).by(-1)
        expect(response).to redirect_to(media_path)
      end
    end

    context 'when logged in as a different user' do
      let(:other_user) { create(:user).tap { |u| u.confirm } }
      let!(:existing_medium) { medium }

      before { sign_in other_user }

      it 'does not delete the medium and redirects' do
        expect {
          delete destroy_media_path(sourcedb: existing_medium.sourcedb, sourceid: existing_medium.sourceid)
        }.not_to change(Medium, :count)
        expect(response).to redirect_to(show_media_path(sourcedb: existing_medium.sourcedb, sourceid: existing_medium.sourceid))
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        delete destroy_media_path(sourcedb: medium.sourcedb, sourceid: medium.sourceid)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /media/bulk_upload' do
    let(:zip_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec', 'fixtures', 'files', 'test_image.png'),
        'application/zip'
      )
    end

    context 'when logged in' do
      before { sign_in user }

      it 'enqueues a job and redirects to new medium page' do
        expect {
          post bulk_upload_media_path, params: { zip_file: zip_file }
        }.to have_enqueued_job(MediaBulkUploadJob)
        expect(response).to redirect_to(new_medium_path)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post bulk_upload_media_path, params: { zip_file: zip_file }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
