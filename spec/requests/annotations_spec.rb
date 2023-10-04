require 'rails_helper'

RSpec.describe "Annotations", type: :request do
  describe "GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/spans/:begin-:end/annotations(.:format)" do
    let(:doc) { create(:doc) }
    let(:base_path) { "/docs/sourcedb/PubMed/sourceid" }

    describe 'document status' do
      subject { response }

      context 'when document is not found' do
        before { get "#{base_path}/123/annotations.json" }

        it { is_expected.to have_http_status(404) }
        it { is_expected.to match_response_body({ message: 'File not found.' }.to_json) }
      end

      context 'when document is found' do
        before { get "#{base_path}/#{doc.sourceid}/annotations.json" }

        it { is_expected.to have_http_status(200) }
        it { is_expected.to match_response_body(doc_as_json(doc)) }
      end
    end

    describe 'partial document annotation' do
      let(:begin_value) { 1 }
      let(:end_value) { 2 }

      before do
        get "#{base_path}/#{doc.sourceid}/spans/#{begin_value}-#{end_value}/annotations.json"
      end

      it 'returns JSON with annotation of part of document' do
        expect(response.body).to eq({
                                      target: "http://test.pubannotation.org#{base_path}/#{doc.sourceid}",
                                      sourcedb: 'PubMed',
                                      sourceid: doc.sourceid,
                                      text: "h",
                                      tracks: []
                                    }.to_json)
      end
    end
  end

  def doc_as_json(doc)
    {
      target: "http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}",
      sourcedb: 'PubMed',
      sourceid: doc.sourceid,
      text: "This is a test.\nTest are implemented.\nImplementation is difficult.",
      tracks: []
    }.to_json
  end

  RSpec::Matchers.define :match_response_body do |expected_body|
    match do |response|
      response.body == expected_body
    end
  end
end
