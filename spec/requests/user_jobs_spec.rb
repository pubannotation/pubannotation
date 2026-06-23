# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Jobs', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:other_user) { create(:user).tap { |u| u.confirm } }
  let(:job) { create(:job, :completed, organization: user) }

  describe 'GET /users/:user_id/jobs/:id' do
    context 'when logged in as the job owner' do
      before { sign_in user }

      it 'renders the job show page' do
        get user_job_path(user.username, job)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not logged in' do
      it 'renders the job show page' do
        get user_job_path(user.username, job)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE /users/:user_id/jobs/:id' do
    context 'when logged in as the job owner' do
      before { sign_in user }

      it 'destroys the job' do
        job
        expect {
          delete user_job_path(user.username, job)
        }.to change(Job, :count).by(-1)
        expect(response).to redirect_to(jobs_media_path)
      end
    end

    context 'when logged in as a different user' do
      before { sign_in other_user }

      it 'does not destroy the job' do
        job
        expect {
          delete user_job_path(user.username, job)
        }.not_to change(Job, :count)
        expect(response).to redirect_to(jobs_media_path)
      end
    end
  end
end
