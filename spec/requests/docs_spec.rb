require 'rails_helper'

RSpec.describe "Docs", type: :request do
  describe "GET /docs(.:format)" do
    subject { response }

    context 'when no docs' do
      before { get "/docs.json" }

      it { is_expected.to have_http_status(200) }
      it { expect(response.body).to eq([].to_json) }
    end

    context 'when there are docs' do
      before do
        create(:doc)
        get "/docs.json"
      end

      it { is_expected.to have_http_status(200) }
      it 'returns the doc data' do
        expected_data = [{
                           sourcedb: "PubMed",
                           sourceid: Doc.last.sourceid,
                           url: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{Doc.last.sourceid}",
                         }]

        expect(response.body).to eq(expected_data.to_json)
      end

      context 'when project name is specified as project_id' do
        before do
          project = create(:project, accessibility: 1)
          create(:project_doc, doc: Doc.last, project: project)
          get "/docs.json?project_id=#{project.name}"
        end

        it { is_expected.to have_http_status(200) }
        it 'returns the doc data' do
          expected_data = [{
                             sourcedb: "PubMed",
                             sourceid: Doc.last.sourceid,
                             url: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{Doc.last.sourceid}",
                           }]

          expect(response.body).to eq(expected_data.to_json)
        end

        context 'when the project is not found' do
          before do
            project = create(:project, name: 'test2')
            create(:project_doc, doc: Doc.last, project: project)
            get "/docs.json?project_id=foo_bar"
          end

          it { is_expected.to have_http_status(422) }
          it { expect(response.body).to eq({message: "Could not find the project."}.to_json) }
        end
      end
    end
  end
end
