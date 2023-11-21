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
        Doc.__elasticsearch__.create_index! force: true
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
            project = create(:project)
            create(:project_doc, doc: Doc.last, project: project)
            get "/docs.json?project_id=foo_bar"
          end

          it { is_expected.to have_http_status(422) }
          it { expect(response.body).to eq({ message: "Could not find the project." }.to_json) }
        end

        context 'when the sourcedb is specified' do
          before do
            project = create(:project, accessibility: 1)
            create(:project_doc, doc: Doc.last, project: project)
            get "/docs.json?project_id=#{project.name}&sourcedb=PubMed"
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
        end
      end

      context 'when the sourcedb is specified' do
        before do
          get "/docs.json?sourcedb=PubMed"
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
      end

      context 'when the keywords "Test" is specified' do
        before do
          # Elasticsearch indexing is asynchronous.
          # For testing purposes, the index is forced to be updated.
          Doc.__elasticsearch__.refresh_index!
          get "/docs.json?keywords=test"
        end

        it { is_expected.to have_http_status(200) }
        it 'returns the doc data' do
          expected_data = [{
                             sourcedb: "PubMed",
                             sourceid: Doc.last.sourceid,
                             url: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{Doc.last.sourceid}",
                             text: ["This is a \u003cem\u003etest\u003c/em\u003e.\n\u003cem\u003eTest\u003c/em\u003e are implemented.\nImplementation is difficult."]
                           }]

          expect(response.body).to eq(expected_data.to_json)
        end

        context 'when html is specified as format' do
          before do
            project = create(:project, accessibility: 1)
            Pubann::Application.config.admin_project_id = project.id
            get "/docs.html?keywords=test"
          end

          it { is_expected.to have_http_status(200) }
          it 'returns the doc data' do
            expect(response.body).to include("/docs/sourcedb/PubMed/sourceid/#{Doc.last.sourceid}")
            expect(response.body).to include("This is a <em>test</em>.\n<em>Test</em> are implemented.\nImplementation is difficult.")
          end
        end

        context 'when tsv is specified as format' do
          before do
            get "/docs.tsv?keywords=test"
          end

          it { is_expected.to have_http_status(200) }
          it 'returns the doc data' do
            expected_header = %w[sourcedb sourceid url text].join("\t")
            expected_data = [
              "PubMed",
              "#{Doc.last.sourceid}",
              "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{Doc.last.sourceid}",
              "\"This is a <em>test</em>.\n<em>Test</em> are implemented.\nImplementation is difficult.\"\n"
            ]

            header, body = response.body.split("\n", 2)
            expect(header).to eq(expected_header)
            expect(body.split("\t")).to eq(expected_data)
          end
        end
      end

      context 'when sort options are specified' do
        before do
          get "/docs.json?sort_key=projects_num&sort_direction=desc&randomize=true"
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
      end

      context 'when the terms "test" is specified' do
        before do
          get "/docs.json?terms=test"
        end

        it { is_expected.to have_http_status(200) }
        it 'returns no doc data' do
          expect(response.body).to eq([].to_json)
        end
      end
    end

    context 'there are docs with annotations' do
      before do
        Doc.__elasticsearch__.create_index! force: true
        create(:doc, :with_annotation)
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

      context 'when the terms "Protein" is specified' do
        before do
          get "/docs.json?terms=Protein"
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
      end
    end
  end
end
