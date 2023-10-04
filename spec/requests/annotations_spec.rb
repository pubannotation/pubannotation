require 'rails_helper'

RSpec.describe "Annotations", type: :request do
  describe "GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations(.:format)" do
    let(:begin_value) { 1 }
    let(:end_value)   { 2 }
    let(:format_value) { :json }

    context 'when document is not found' do
      before do
        get doc_sourcedb_sourceid_path(sourcedb: 'abc', sourceid: '123', begin: begin_value, end: end_value, format: format_value)
      end

      it "returns 404 response" do
        expect(response).to have_http_status(404)
      end

      it "returns JSON" do
        expect(response.body).to eq({ message: 'File not found.' }.to_json)
      end
    end

    context 'when document is found' do
      let(:doc) { create(:doc) }

      before do
        get doc_sourcedb_sourceid_path(sourcedb: 'PubMed', sourceid: doc.sourceid, begin: begin_value, end: end_value, format: format_value)
      end

      it 'returns 200 response' do
        expect(response).to have_http_status(200)
      end

      it 'returns JSON' do
        expect(response.body).to eq({
                                      target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
                                      sourcedb: 'PubMed',
                                      sourceid: doc.sourceid,
                                      text: "h",
                                      tracks: []
                                    }.to_json)
      end
    end
  end
end
