require 'rails_helper'

RSpec.describe "Annotations", type: :request do
  describe "GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations(.:format)" do
    context 'when document is not found' do
      it "returns 404 response" do
        get doc_sourcedb_sourceid_path sourcedb: 'abc', sourceid: '123', begin: 1, end: 2, format: :json
        expect(response).to have_http_status(404)
      end

      it "returns JSON" do
        get doc_sourcedb_sourceid_path sourcedb: 'abc', sourceid: '123', begin: 1, end: 2, format: :json
        expect(response.body).to eq({ message: 'File not found.' }.to_json)
      end
    end

    context 'when document is found' do
      before do
        create(:doc)
      end

      it 'returns 200 response' do
        get doc_sourcedb_sourceid_path sourcedb: 'PubMed', sourceid: '12345678', begin: 1, end: 2, format: :json
        expect(response).to have_http_status(200)
      end

      it 'returns JSON' do
        get doc_sourcedb_sourceid_path sourcedb: 'PubMed', sourceid: '12345678', begin: 1, end: 2, format: :json
        expect(response.body).to eq({
                                      target: 'http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/12345678' ,
                                      sourcedb: 'PubMed',
                                      sourceid: '12345678',
                                      text: "h",
                                      tracks: []
                                    }.to_json)
      end
    end
  end
end
