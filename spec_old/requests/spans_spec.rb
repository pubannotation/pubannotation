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

      it 'returns text of document' do
        get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

        expect(JSON.parse(response.body)['text']).to eq(doc.body)
      end

      context 'when document has denotations' do
        let(:project) { create(:project) }
        let!(:denotation) { create(:denotation, project: project, doc: doc) }
        let!(:object_denotation) { create(:object_denotation, project: project, doc: doc) }

        it "returns 200 response" do
          get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(response).to have_http_status(200)
        end

        it 'returns denotations of document' do
          get doc_sourcedb_sourceid_spans_path sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(JSON.parse(response.body)['denotations']).to eq([
            {
              "id" => "T1",
              "obj" => "http://www.example.com/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}/spans/0-4",
              "span"=>{"begin"=>0, "end"=>4}
            },
            {
              "id" => "T2",
              "obj" => "http://www.example.com/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}/spans/10-14",
              "span"=>{"begin"=>10, "end"=>14}
            }
                                                                 ])
        end
      end
    end
  end

  describe "GET /projects/:project_id/docs/sourcedb/:sourcedb/sourceid/:sourceid/spans" do
    context 'when project is not found' do
      it "returns 422 response" do
        get spans_index_project_sourcedb_sourceid_docs_path project_id: 0, sourcedb: 'abc', sourceid: '123', format: :json
        expect(response).to have_http_status(422)
      end
    end

    context 'when project is found' do
      let(:project) { create(:project, accessibility: 1) }

      context 'when document is not found' do
        it "returns 422 response" do
          get spans_index_project_sourcedb_sourceid_docs_path project_id: project.name, sourcedb: 'abc', sourceid: '123', format: :json
          expect(response).to have_http_status(422)
        end
      end

      context 'when document is found' do
        let(:doc) { create(:doc) }
        let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

        it "returns 200 response" do
          get spans_index_project_sourcedb_sourceid_docs_path project_id: project.name, sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(response).to have_http_status(200)
        end

        it "returns text of document" do
          get spans_index_project_sourcedb_sourceid_docs_path project_id: project.name, sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

          expect(JSON.parse(response.body)['text']).to eq(doc.body)
        end

        context 'when document has denotations' do
          let!(:denotation) { create(:denotation, project: project, doc: doc) }
          let!(:object_denotation) { create(:object_denotation, project: create(:project, name: 'another_project')) }

          it "returns 200 response" do
            get spans_index_project_sourcedb_sourceid_docs_path project_id: project.name, sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

            expect(response).to have_http_status(200)
          end

          it 'returns denotations in project' do
            get spans_index_project_sourcedb_sourceid_docs_path project_id: project.name, sourcedb: 'PubMed', sourceid: doc.sourceid, format: :json

            expect(JSON.parse(response.body)['denotations']).to eq([
              {
                "id" => "T1",
                "obj" => "http://www.example.com/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}/spans/0-4",
                "span"=>{"begin"=>0, "end"=>4}
              }
                                                                     ])
          end
        end
      end
    end
  end

  describe "POST /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans" do
    context 'when document is not found and cannot be fetched' do
      before do
        allow(Doc).to receive(:sequence_and_store_doc!).and_raise(StandardError, "Document not found")
      end

      it "returns 422 response" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: 'PMC', sourceid: '999999'), params: { text: 'some text' }
        expect(response).to have_http_status(422)
      end
    end

    context 'when text parameter is missing' do
      let(:doc) { create(:doc) }

      it "returns 422 response with error message" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid)
        expect(response).to have_http_status(422)
        expect(response.body).to include("The 'text' parameter is missing")
      end
    end

    context 'when text is found in document' do
      let(:doc) { create(:doc, body: "This is a test document. It contains sample text for testing alignment.") }

      it "returns 200 response" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'sample text' }
        expect(response).to have_http_status(200)
      end

      it "returns URL with correct span positions" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'sample text' }

        # The text "sample text" should be found at position 37-48 in the document
        expected_url = "http://www.example.com/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/spans/37-48"
        expect(response.body).to eq(expected_url)
      end

      it "sets Location header to the URL" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'sample text' }

        expected_url = "http://www.example.com/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/spans/37-48"
        expect(response.headers['Location']).to eq(expected_url)
      end

      it "finds text at the beginning of document" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'This is a test' }

        expect(response).to have_http_status(200)
        expect(response.body).to include('/spans/0-14')
      end

      it "finds text at the end of document" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'testing alignment.' }

        expect(response).to have_http_status(200)
        expect(response.body).to include('/spans/53-71')
      end

      it "handles text with whitespace variations" do
        # TextAlignment should handle minor whitespace differences
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'sample  text' }

        expect(response).to have_http_status(200)
        expect(response.body).to match(%r{/spans/\d+-\d+})
      end
    end

    context 'when text cannot be found in document' do
      let(:doc) { create(:doc, body: "This is a test document.") }

      it "returns 422 response" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'nonexistent text that is not in the document' }

        expect(response).to have_http_status(422)
      end

      it "returns error message" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'nonexistent text' }

        expect(response.body).to include("Text could not be found in the document")
      end
    end

    context 'when text is an exact substring match' do
      let(:doc) { create(:doc, body: "The quick brown fox jumps over the lazy dog.") }

      it "finds exact match correctly" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: 'brown fox' }

        expect(response).to have_http_status(200)
        expect(response.body).to include('/spans/10-19')
      end
    end

    context 'with leading and trailing whitespace in text parameter' do
      let(:doc) { create(:doc, body: "Test document with content.") }

      it "strips whitespace and finds text" do
        post doc_sourcedb_sourceid_spans_path(sourcedb: doc.sourcedb, sourceid: doc.sourceid), params: { text: '  with content  ' }

        expect(response).to have_http_status(200)
        expect(response.body).to match(%r{/spans/\d+-\d+})
      end
    end
  end
end
