require 'rails_helper'

RSpec.describe "Json2inline", type: :request do
  describe "POST /conversions/json2inline" do
    let(:json_annotation) { '{ "text": "sample text" }' }

    context 'when requested with valid JSON' do
      it 'returns 200 ok' do
        post "/conversions/json2inline", params: json_annotation,
                                         headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(200)
      end
    end

    context 'when requested with invalid JSON' do
      it 'returns 400 bad request' do
        post "/conversions/json2inline", params: '{ invalid_json }',
                                         headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(400)
      end
    end

    context 'when requested without content-type' do
      it 'returns 415 unsupported_media_type' do
        post "/conversions/json2inline", params: json_annotation

        expect(response).to have_http_status(415)
      end
    end

    context 'when requested with invalid content-type' do
      it 'returns 415 unsupported_media_type' do
        post "/conversions/json2inline", params: json_annotation,
                                         headers: { 'Content-Type' => 'text/plain' }

        expect(response).to have_http_status(415)
      end
    end
  end
end
