# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media::MessagesController', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:other_user) { create(:user).tap { |u| u.confirm } }
  let(:job) { create(:job, organization: user) }
  let!(:message) do
    job.add_message(sourcedb: 'PMC', sourceid: '1', body: 'something went wrong')
    job.messages.last
  end

  describe 'GET /media/jobs/:job_id/messages/:id' do
    context 'when logged in as the job owner' do
      before { sign_in user }

      it 'renders the show page' do
        get media_job_message_path(job, message)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when logged in as a different user' do
      before { sign_in other_user }

      it 'redirects to the media jobs page' do
        get media_job_message_path(job, message)
        expect(response).to redirect_to(media_jobs_path)
        expect(flash[:notice]).to eq('Could not find the message.')
      end
    end

    context 'when the message does not exist' do
      before { sign_in user }

      it 'redirects to the media jobs page' do
        get media_job_message_path(job, id: 'does-not-exist')
        expect(response).to redirect_to(media_jobs_path)
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get media_job_message_path(job, message)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as a user who cannot access media' do
      let(:restricted_user) { create(:user, can_use_media: false).tap { |u| u.confirm } }
      let(:job) { create(:job, organization: restricted_user) }

      before { sign_in restricted_user }

      it 'returns forbidden' do
        get media_job_message_path(job, message)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
