# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocRdfExporter, type: :model do
  let(:doc) { build(:doc, sourcedb: 'PMC', sourceid: '123', body: 'some text') }
  let(:exporter) { described_class.new(doc) }
  let(:target) { Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url('PMC', '123', only_path: false) }

  it 'exposes the collection and document graph URIs' do
    expect(described_class.graph_uri).to eq('https://pubannotation.org/docs')
    expect(exporter.graph_uri).to eq(target)
  end

  describe '#get_denotations_hash_all' do
    it 'exports denotations and blocks from the requested projects with document metadata' do
      doc.save!
      projects = create_list(:project, 3)
      denotation = create(:denotation, doc: doc, project: projects[0])
      block = create(:block, doc: doc, project: projects[1], end: 9)
      create(:denotation, doc: doc, project: projects[2])

      expect(exporter.get_denotations_hash_all(projects.first(2).map(&:id))).to eq(
        denotations: [denotation.as_json, block.as_json],
        target: target, sourcedb: 'PMC', sourceid: '123', text: 'some text'
      )
      expect(exporter.get_denotations_hash_all[:denotations].size).to eq(3)
      expect(exporter.get_denotations_hash_all(projects[0].id)[:denotations]).to eq([denotation.as_json])
    end
  end

  describe '#get_spans_rdf' do
    let(:rdfizer) { instance_double(TAO::RDFizer) }
    let(:spans) { { denotations: [{ id: 'T1', span: { begin: 0, end: 4 }, obj: 'Entity' }] } }

    before do
      allow(TAO::RDFizer).to receive(:new).with(:spans).and_return(rdfizer)
      allow(exporter).to receive(:get_denotations_hash_all).with(42).and_return(spans)
    end

    it 'generates the document spans graph without prefixes by default' do
      travel_to Time.utc(2026, 10, 29, 1, 2, 3) do
        expect(rdfizer).to receive(:rdfize).with([spans], { with_prefixes: false }).and_return("first .\nsecond .")

        expect(exporter.get_spans_rdf(42)).to eq(
          "<#{target}/spans> rdf:type oa:Annotation ;\n" \
          "\toa:has_body <#{target}/spans> ;\n" \
          "\toa:has_target <#{target}> ;\n" \
          "\tprov:generatedAtTime \"#{DateTime.now.iso8601}\"^^xsd:dateTime .\n\n" \
          "GRAPH <#{target}/spans>\n{\n\tfirst .\n\tsecond .\n}\n"
        )
      end
    end

    it 'includes RDFizer, OA and PROV prefixes when requested' do
      expect(rdfizer).to receive(:rdfize).with([spans], { only_prefixes: true }).and_return("@prefix ex: <https://example.org/> .\n")
      expect(rdfizer).to receive(:rdfize).with([spans], { with_prefixes: false }).and_return('triple .')

      expect(exporter.get_spans_rdf(42, { with_prefixes: true })).to start_with(
        "@prefix ex: <https://example.org/> .\n" \
        "@prefix oa: <http://www.w3.org/ns/oa#> .\n" \
        "@prefix prov: <http://www.w3.org/ns/prov#> .\n\n"
      )
    end

    it 'returns empty output without invoking RDFizer when there are no spans' do
      spans[:denotations] = []
      expect(rdfizer).not_to receive(:rdfize)

      expect(exporter.get_spans_rdf(42)).to eq('')
    end
  end
end
