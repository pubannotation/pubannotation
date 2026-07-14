# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media::JobsController', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:other_user) { create(:user).tap { |u| u.confirm } }

  describe 'GET /media/jobs' do
    context 'when logged in' do
      before { sign_in user }

      it 'renders the jobs list' do
        get media_jobs_path
        expect(response).to have_http_status(:ok)
      end

      it 'renders the jobs list when a job has messages' do
        job = create(:job, organization: user)
        job.add_message(sourcedb: 'PMC', sourceid: '1', body: 'something went wrong')

        get media_jobs_path

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get media_jobs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        get media_jobs_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /media/jobs/latest_jobs_table' do
    context 'when logged in' do
      before { sign_in user }

      it 'renders the jobs table partial' do
        get latest_jobs_table_media_jobs_path
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get latest_jobs_table_media_jobs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        get latest_jobs_table_media_jobs_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /media/jobs/:id' do
    let(:job) { create(:job, organization: user) }

    context 'when logged in as the job owner' do
      before { sign_in user }

      it 'renders the show page' do
        get media_job_path(job)
        expect(response).to have_http_status(:ok)
      end

      it 'renders the show page when the job has messages' do
        job.add_message(sourcedb: 'PMC', sourceid: '1', body: 'something went wrong')

        get media_job_path(job)

        expect(response).to have_http_status(:ok)
      end

      it 'shows a link to each message' do
        job.add_message(sourcedb: 'PMC', sourceid: '1', body: 'something went wrong')
        message = job.messages.last

        get media_job_path(job)

        expect(response.body).to include(media_job_message_path(job, message))
      end
    end

    context "when logged in as a different user" do
      before { sign_in other_user }

      it 'redirects to the media jobs page' do
        get media_job_path(job)
        expect(response).to redirect_to(media_jobs_path)
        expect(flash[:notice]).to eq('Could not find the job.')
      end
    end

    context 'when the job does not exist' do
      before { sign_in user }

      it 'redirects to the media jobs page' do
        get media_job_path(id: 'does-not-exist')
        expect(response).to redirect_to(media_jobs_path)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get media_job_path(job)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }
      let!(:job) { create(:job, organization: restricted_user) }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        get media_job_path(job)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
