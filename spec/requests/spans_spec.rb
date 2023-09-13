require 'rails_helper'

RSpec.describe "Spans", type: :request do
  describe "GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans" do
    context 'when document is not found' do
      it "returns 422 response" do
        get doc_sourcedb_sourceid_spans_path sourcedb: 'abc', sourceid: '123', format: :json
        expect(response).to have_http_status(422)
      end
    end

    context 'when document is found' do
      let(:doc) { create(:doc) }

      it "returns 200 response" do
        get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

        expect(response).to have_http_status(200)
      end

      it 'returns text of doc' do
        get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

        expect(JSON.parse(response.body)['text']).to eq(doc.body)
      end

      context 'when doc has denotations' do
        let(:project) { create(:project) }
        let!(:denotation) { create(:denotation, project: project, doc: doc) }
        let!(:object_denotation) { create(:object_denotation, project: project, doc: doc) }

        it "returns 200 response" do
          get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(response).to have_http_status(200)
        end

        it 'returns denotations of foc' do
          get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(JSON.parse(response.body)['denotations']).to eq([
            {
              "id" => "T1",
              "obj" => "http://www.example.com/docs/sourcedb/PubMed/sourceid/4/spans/0-4",
              "span"=>{"begin"=>0, "end"=>4}
            },
            {
              "id" => "T2",
              "obj" => "http://www.example.com/docs/sourcedb/PubMed/sourceid/4/spans/10-14",
              "span"=>{"begin"=>10, "end"=>14}
            }
                                                                 ])
        end
      end
    end
  end
end
