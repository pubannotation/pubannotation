# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium) }

  before do
    request.env['HTTP_AUTHORIZATION'] =
      ActionController::HttpAuthentication::Basic.encode_credentials(user.email, 'password')
  end

  describe 'POST #create' do
    context 'when media is specified and exists' do
      it 'creates a doc linked to the medium' do
        post :create, params: {
          project_id: project.name,
          doc: { body: 'doctor findings', sourcedb: 'Example', sourceid: '001' },
          commit: 'Create',
          media: { sourcedb: medium.sourcedb, sourceid: medium.sourceid }
        }, format: :json

        expect(response).to have_http_status(:created)
        expect(Doc.last.medium).to eq(medium)
      end
    end

    context 'when media is not specified' do
      it 'creates a doc without medium' do
        post :create, params: {
          project_id: project.name,
          doc: { body: 'doctor findings', sourcedb: 'Example', sourceid: '001' },
          commit: 'Create'
        }, format: :json

        expect(response).to have_http_status(:created)
        expect(Doc.last.medium).to be_nil
      end
    end

    context 'when specified media does not exist' do
      it 'returns an error' do
        post :create, params: {
          project_id: project.name,
          doc: { body: 'doctor findings', sourcedb: 'Example', sourceid: '001' },
          commit: 'Create',
          media: { sourcedb: 'NonExistentDB', sourceid: 'nonexistent-001' }
        }, format: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
