require 'rails_helper'

RSpec.describe "Spans", type: :request do
  describe "POST /conversions/inline2json" do
    context 'when requested with body' do
      it 'returns 200 ok' do
        post "/conversions/inline2json", params: '[Elon Musk][Person] is a member of the PayPal Mafia.',
                                         headers: { 'Content-Type' => 'text/markdown' }

        expect(response).to have_http_status(200)
      end
    end

    context 'when requested without body' do
      it 'returns 200 ok' do
        post "/conversions/inline2json", headers: { 'Content-Type' => 'text/markdown' }

        expect(response).to have_http_status(200)
      end
    end

    context 'when payload size exceeds the limit' do
      let(:large_payload) { "A" * 10.megabytes }

      it 'returns 413 payload too large' do
        post "/conversions/inline2json", params: large_payload,
                                         headers: { 'Content-Type' => 'text/markdown' }

        expect(response).to have_http_status(:payload_too_large)
      end
    end
  end
end
