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
  let(:video_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4'),
      'video/mp4'
    )
  end
  let(:audio_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3'),
      'audio/mpeg'
    )
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

      it 'creates a medium with valid params and derives media_type from the file' do
        expect {
          post media_path, params: {
            medium: {
              sourcedb: 'TestDB',
              sourceid: 'img-001',
              file: image_file
            }
          }
        }.to change(Medium, :count).by(1)
        expect(Medium.last.media_type).to eq('image')
        expect(response).to redirect_to(new_medium_path)
      end

      it 'creates a medium with a video file' do
        expect {
          post media_path, params: {
            medium: {
              sourcedb: 'TestDB',
              sourceid: 'video-001',
              file: video_file
            }
          }
        }.to change(Medium, :count).by(1)
        expect(Medium.last.media_type).to eq('video')
      end

      it 'creates a medium with an audio file' do
        expect {
          post media_path, params: {
            medium: {
              sourcedb: 'TestDB',
              sourceid: 'audio-001',
              file: audio_file
            }
          }
        }.to change(Medium, :count).by(1)
        expect(Medium.last.media_type).to eq('audio')
      end

      it 'renders new with invalid params' do
        post media_path, params: {
          medium: {
            sourcedb: '',
            sourceid: 'img-001'
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post media_path, params: {
          medium: { sourcedb: 'TestDB', sourceid: 'img-001' }
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

      context 'when job count is under 10' do
        it 'enqueues a job and redirects to new medium page' do
          expect {
            post bulk_upload_media_path, params: { zip_file: zip_file }
          }.to have_enqueued_job(MediaBulkUploadJob)
          expect(response).to redirect_to(new_medium_path)
        end
      end

      context 'when job count is 10 or more' do
        before do
          10.times { create(:job, organization: user) }
        end

        it 'does not enqueue a job and redirects to new medium page with notice' do
          expect {
            post bulk_upload_media_path, params: { zip_file: zip_file }
          }.not_to have_enqueued_job(MediaBulkUploadJob)
          expect(response).to redirect_to(new_medium_path)
          expect(flash[:notice]).to include('Up to 10 jobs')
        end
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post bulk_upload_media_path, params: { zip_file: zip_file }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE /media/jobs' do
    context 'when logged in' do
      before { sign_in user }

      it 'destroys finished jobs but keeps unfinished ones' do
        finished_job = create(:job, :completed, organization: user)
        unfinished_job = create(:job, organization: user)

        expect {
          delete media_clear_finished_jobs_path
        }.to change(Job, :count).by(-1)

        expect(Job.exists?(finished_job.id)).to be false
        expect(Job.exists?(unfinished_job.id)).to be true
        expect(response).to redirect_to(media_jobs_path)
        expect(flash[:notice]).to eq('Finished jobs cleared.')
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        delete media_clear_finished_jobs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        delete media_clear_finished_jobs_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
