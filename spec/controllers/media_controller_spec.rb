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
end
