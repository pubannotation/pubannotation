require 'rails_helper'

RSpec.describe "Spans", type: :request do
  describe "POST /conversions/inline2json" do
    context 'when requested with body' do
      it 'returns 200 ok' do
        post "/conversions/inline2json", params: '[Elon Musk][Person] is a member of the PayPal Mafia.',
                                         headers: { 'Content-Type' => 'text/plain' }

        expect(response).to have_http_status(200)
      end
    end

    context 'when requested without body' do
      it 'returns 200 ok' do
        post "/conversions/inline2json", headers: { 'Content-Type' => 'text/plain' }

        expect(response).to have_http_status(200)
      end
    end

    context 'when payload size exceeds the limit' do
      let(:large_payload) { "A" * 10.megabytes }

      it 'returns 413 payload too large' do
        post "/conversions/inline2json", params: large_payload,
                                         headers: { 'Content-Type' => 'text/plain' }

        expect(response).to have_http_status(:payload_too_large)
      end
    end

    context 'when no content-type specified' do
      it 'returns 415 unsupported_media_type' do
        post "/conversions/inline2json"

        expect(response).to have_http_status(415)
      end
    end
  end
end
