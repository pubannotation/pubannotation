# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, '#create_annotations_RDF' do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:rdf_loc) { Dir.mktmpdir }
  let(:rdfizer) { instance_double(TAO::RDFizer) }

  before do
    allow(TAO::RDFizer).to receive(:new).with(:annotations).and_return(rdfizer)
    allow(rdfizer).to receive(:rdfize).and_return('')
  end

  after do
    FileUtils.remove_entry(rdf_loc) if File.exist?(rdf_loc)
  end

  def create_doc_with_denotation(project)
    doc = create(:doc)
    create(:project_doc, project: project, doc: doc)
    create(:denotation, project: project, doc: doc)
    doc
  end

  describe 'batch loading of docs' do
    it 'loads docs in batches rather than one at a time' do
      docs = 3.times.map { create_doc_with_denotation(project) }
      doc_ids = docs.map(&:id)

      # Expect a single WHERE query per batch, not individual finds
      expect(Doc).to receive(:where).with(id: doc_ids).and_call_original
      expect(Doc).not_to receive(:find)

      project.create_annotations_RDF(doc_ids, rdf_loc)
    end

    it 'yields continuous indices across batch boundaries' do
      docs = 3.times.map { create_doc_with_denotation(project) }
      doc_ids = docs.map(&:id)

      yielded_indices = []
      project.create_annotations_RDF(doc_ids, rdf_loc) do |i, doc, message|
        yielded_indices << i
      end

      expect(yielded_indices).to eq([0, 1, 2])
    end

    it 'skips docs that no longer exist' do
      doc = create_doc_with_denotation(project)
      missing_id = doc.id + 9999

      yielded_docs = []
      project.create_annotations_RDF([missing_id, doc.id], rdf_loc) do |i, doc, _msg|
        yielded_docs << doc
      end

      expect(yielded_docs.compact).to eq([doc])
    end
  end

  describe 'hannotations reuse for first doc' do
    it 'calls hannotations only once for the first doc' do
      doc = create_doc_with_denotation(project)
      hannotations_result = { text: 'test', denotations: [] }

      expect(doc).to receive(:hannotations).with(project, nil, nil).once.and_return(hannotations_result)
      allow(Doc).to receive(:where).and_return(Doc.where(id: doc.id))
      allow(Doc.where(id: doc.id)).to receive(:index_by).and_return({ doc.id => doc })

      project.create_annotations_RDF([doc.id], rdf_loc)
    end

    it 'calls hannotations independently for subsequent docs' do
      doc1 = create_doc_with_denotation(project)
      doc2 = create_doc_with_denotation(project)

      # doc1 is first: hannotations called once (reused for prefix + rdf)
      # doc2 is second: hannotations called once (for rdf only)
      allow_any_instance_of(Doc).to receive(:hannotations).and_return({ text: 'test', denotations: [] })

      call_counts = Hash.new(0)
      allow(doc1).to receive(:hannotations) { call_counts[doc1.id] += 1; { text: 'test', denotations: [] } }
      allow(doc2).to receive(:hannotations) { call_counts[doc2.id] += 1; { text: 'test', denotations: [] } }

      docs_hash = { doc1.id => doc1, doc2.id => doc2 }
      allow(Doc).to receive(:where).and_return(double(index_by: docs_hash))

      project.create_annotations_RDF([doc1.id, doc2.id], rdf_loc)

      expect(call_counts[doc1.id]).to eq(1)
      expect(call_counts[doc2.id]).to eq(1)
    end
  end

  describe 'yielding progress' do
    it 'yields index, doc, and nil for each doc' do
      docs = 3.times.map { create_doc_with_denotation(project) }
      doc_ids = docs.map(&:id)

      yielded = []
      project.create_annotations_RDF(doc_ids, rdf_loc) do |i, doc, message|
        yielded << [i, doc.id, message]
      end

      expect(yielded.length).to eq(3)
      yielded.each_with_index do |(idx, _doc_id, msg), expected_idx|
        expect(idx).to eq(expected_idx)
        expect(msg).to be_nil
      end
    end
  end

  describe 'error handling' do
    it 'yields error message and continues when block given' do
      doc = create_doc_with_denotation(project)

      allow(rdfizer).to receive(:rdfize).and_raise(RuntimeError, 'rdf error')

      yielded = []
      project.create_annotations_RDF([doc.id], rdf_loc) do |i, doc, message|
        yielded << [i, message]
      end

      expect(yielded.length).to eq(1)
      expect(yielded.first[1]).to include('rdf error')
    end

    it 'raises error when no block given' do
      doc = create_doc_with_denotation(project)

      allow(rdfizer).to receive(:rdfize).and_raise(RuntimeError, 'rdf error')

      expect {
        project.create_annotations_RDF([doc.id], rdf_loc)
      }.to raise_error(RuntimeError, 'rdf error')
    end
  end

  describe 'output file' do
    it 'writes a trig file with preamble and closing brace' do
      doc = create_doc_with_denotation(project)
      allow(rdfizer).to receive(:rdfize).and_return("@prefix ex: <http://example.org/> .\n")

      project.create_annotations_RDF([doc.id], rdf_loc)

      filename = project.send(:annotations_rdf_filename)
      content = File.read(File.join(rdf_loc, filename))

      expect(content).to include('@prefix')
      expect(content).to include('GRAPH')
      expect(content.strip).to end_with('}')
    end
  end
end
