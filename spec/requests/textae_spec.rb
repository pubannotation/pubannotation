require 'rails_helper'

RSpec.describe "Textae", type: :request do
  describe "POST /textae" do
    let(:json_annotation) do
      <<~JSON
        {
          "text": "Elon Musk is a member of the PayPal Mafia.",
          "denotations":[
            {"span":{"begin": 0, "end": 9}, "obj":"Person"}
          ]
        }
    JSON
    end
    let(:inline_annotation) do
      <<~INLINE
        [Elon Musk][Person] is a member of the [PayPal Mafia][Organization].

        [Person]: https://example.com/Person
        [Organization]: https://example.com/Organization
      INLINE
    end

    context 'when requested with json annotation' do
      it 'should be created' do
        count = TextaeAnnotation.count
        post "/textae", params: json_annotation, headers: { 'Content-Type' => 'application/json' }

        expect(TextaeAnnotation.count).to eq(count + 1)
      end
    end

    context 'when requested with inline markdown' do
      it 'should be created' do
        count = TextaeAnnotation.count
        post "/textae", params: inline_annotation, headers: { 'Content-Type' => 'text/markdown' }

        expect(TextaeAnnotation.count).to eq(count + 1)
      end

      it 'should be saved as JSON' do
        post "/textae", params: inline_annotation, headers: { 'Content-Type' => 'text/markdown' }
        created_annotation = TextaeAnnotation.last.annotation

        expect { JSON.parse(created_annotation) }.not_to raise_error
      end
    end

    context 'when content-type invalid' do
      it 'returns 415 unsupported_media_type' do
        post "/textae", params: json_annotation

        expect(response).to have_http_status(415)
      end
    end
  end

  describe 'GET /textae/:uuid' do
    context 'when requested with valid uuid' do
      it 'returns 200 ok' do
        textae_annotation = TextaeAnnotation.create(annotation: '{ "text": "hello world" }')

        get "/textae/#{textae_annotation.uuid}"

        expect(response).to have_http_status(200)
      end
    end

    context 'when request with invalid uuid' do
      it 'returns 404 not found' do
        get '/textae/123456'

        expect(response).to have_http_status(404)
      end
    end
  end
end
