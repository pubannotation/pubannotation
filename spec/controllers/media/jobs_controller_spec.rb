# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media::JobsController', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:other_user) { create(:user).tap { |u| u.confirm } }

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
    end

    context "when logged in as a different user" do
      before { sign_in other_user }

      it 'redirects to the media jobs page' do
        get media_job_path(job)
        expect(response).to redirect_to(jobs_media_path)
        expect(flash[:notice]).to eq('Could not find the job.')
      end
    end

    context 'when the job does not exist' do
      before { sign_in user }

      it 'redirects to the media jobs page' do
        get media_job_path(id: 'does-not-exist')
        expect(response).to redirect_to(jobs_media_path)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get media_job_path(job)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE /media/jobs/:id' do
    context 'when the job is not running' do
      let!(:job) { create(:job, :completed, organization: user) }

      before { sign_in user }

      it 'destroys the job and redirects to the media jobs page' do
        expect {
          delete media_job_path(job)
        }.to change(Job, :count).by(-1)
        expect(response).to redirect_to(jobs_media_path)
      end
    end

    context 'when the job is running' do
      let!(:job) { create(:job, organization: user) }

      before { sign_in user }

      it 'does not destroy the job' do
        expect {
          delete media_job_path(job)
        }.not_to change(Job, :count)
        expect(response).to redirect_to(jobs_media_path)
      end
    end

    context "when logged in as a different user" do
      let!(:job) { create(:job, :completed, organization: user) }

      before { sign_in other_user }

      it 'does not destroy the job' do
        expect {
          delete media_job_path(job)
        }.not_to change(Job, :count)
        expect(response).to redirect_to(jobs_media_path)
      end
    end

    context 'when not logged in' do
      let!(:job) { create(:job, :completed, organization: user) }

      it 'redirects to login' do
        delete media_job_path(job)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
