require 'rails_helper'

RSpec.describe "Annotations", type: :request do
  BASE_PATH = "/docs/sourcedb/PubMed/sourceid".freeze

  describe "GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations(.:format)" do
    let(:doc) { create(:doc) }

    def get_annotation(source_id, begin_value: nil, end_value: nil, terms: nil, predicates: nil)
      url = "#{BASE_PATH}/#{source_id}"
      url += "/spans/#{begin_value}-#{end_value}" if begin_value && end_value
      get "#{url}/annotations.json" + (terms ? "?terms=#{terms}" : "") + (predicates ? "&predicates=#{predicates}" : "")
    end

    describe 'document status' do
      subject { response }

      context 'when document is not found' do
        before { get_annotation(123) }

        it { is_expected.to have_http_status(404) }
        it { is_expected.to match_response_body({ message: 'File not found.' }.to_json) }
      end

      context 'when document is found' do
        before { get_annotation(doc.sourceid) }

        it { is_expected.to have_http_status(200) }
        it { is_expected.to match_response_body(doc_as_json(doc)) }
      end
    end

    describe 'partial document annotation' do
      let(:begin_value) { 1 }
      let(:end_value) { 2 }

      before { get_annotation(doc.sourceid, begin_value:, end_value:) }

      it 'returns JSON with annotation of part of document' do
        expect(response.body).to eq(doc_as_json(doc, 'h'))
      end
    end

    describe 'full document annotation' do
      context 'when document has annotations' do
        let(:doc) { create(:doc, :with_annotation) }

        before { get_annotation(doc.sourceid) }

        it 'returns JSON' do
          expect(response.body).to eq(doc_as_json_with_annotations(doc))
        end
      end

      context 'term is specified' do
        let(:doc) { create(:doc, :with_annotation) }

        before { get_annotation(doc.sourceid, terms: 'Protein,true') }

        it 'returns JSON' do
          expect(response.body).to eq({
                                        target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
                                        sourcedb: 'PubMed',
                                        sourceid: doc.sourceid,
                                        text: "This is a test.\nTests are implemented.\nImplementation is difficult.",
                                        tracks: [
                                          {
                                            project: doc.projects.first.name,
                                            denotations: [
                                              {
                                                id: "T1",
                                                span: {
                                                  begin: 0,
                                                  end: 4
                                                },
                                                obj: "subject"
                                              }
                                            ],
                                            blocks: [
                                              {
                                                id: "B1",
                                                span: {
                                                  begin: 0,
                                                  end: 14
                                                },
                                                obj: "1st line"
                                              }
                                            ],
                                            "attributes" => [
                                              {
                                                "id" => "A1",
                                                "pred" => "type",
                                                "subj" => "T1",
                                                "obj" => "Protein"
                                              },
                                              {
                                                "id" => "A2",
                                                "pred" => "suspect",
                                                "subj" => "B1",
                                                "obj" => "true"
                                              }
                                            ]
                                          }
                                        ]
                                      }.to_json)
        end
      end

      context 'terms and predicates are specified' do
        let(:doc) { create(:doc, :with_annotation) }

        before { get_annotation(doc.sourceid, terms: 'Protein,true', predicates: 'type') }

        it 'returns JSON' do
          expect(response.body).to eq({
                                        target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
                                        sourcedb: 'PubMed',
                                        sourceid: doc.sourceid,
                                        text: "This is a test.\nTests are implemented.\nImplementation is difficult.",
                                        tracks: [
                                          {
                                            project: doc.projects.first.name,
                                            denotations: [
                                              {
                                                id: "T1",
                                                span: {
                                                  begin: 0,
                                                  end: 4
                                                },
                                                obj: "subject"
                                              }
                                            ],
                                            "attributes" => [
                                              {
                                                "id" => "A1",
                                                "pred" => "type",
                                                "subj" => "T1",
                                                "obj" => "Protein"
                                              }
                                            ]
                                          }
                                        ]
                                      }.to_json)
        end
      end
    end

  end


  def doc_as_json(doc, text = nil)
    {
      target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
      sourcedb: 'PubMed',
      sourceid: doc.sourceid,
      text: text || "This is a test.\nTests are implemented.\nImplementation is difficult.",
      tracks: []
    }.to_json
  end

  def doc_as_json_with_annotations(doc)
    {
      target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
      sourcedb: 'PubMed',
      sourceid: doc.sourceid,
      text: "This is a test.\nTests are implemented.\nImplementation is difficult.",
      tracks: [
        {
          project: doc.projects.first.name,
          denotations: [
            {
              id: "T1",
              span: {
                begin: 0,
                end: 4
              },
              obj: "subject"
            },
            {
              id: "T2",
              span: {
                begin: 10,
                end: 14
              },
              obj: "object"
            }
          ],
          "blocks" => [
            {
              "id" => "B1",
              "span" => {
                "begin" => 0,
                "end" => 14
              },
              "obj" => "1st line"
            },
            {
              "id" => "B2",
              "span" => {
                "begin" => 16,
                "end" => 37
              },
              "obj" => "2nd line"
            }
          ],
          "relations" => [
            {
              "id" => "R1",
              "pred" => "predicate",
              "subj" => "T1",
              "obj" => "T2"
            },
            {
              "id" => "S1",
              "pred" => "next",
              "subj" => "B1",
              "obj" => "B2"
            }
          ],
          "attributes" => [
            {
              "id" => "A1",
              "pred" => "type",
              "subj" => "T1",
              "obj" => "Protein"
            },
            {
              "id" => "A2",
              "pred" => "suspect",
              "subj" => "B1",
              "obj" => "true"
            }
          ]
        }
      ]
    }.to_json
  end

  RSpec::Matchers.define :match_response_body do |expected_body|
    match do |response|
      response.body == expected_body
    end
  end
end
