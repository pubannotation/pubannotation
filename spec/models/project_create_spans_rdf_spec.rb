# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, '#create_spans_RDF' do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:rdf_dir) { Dir.mktmpdir }
  let(:rdf_loc) { rdf_dir + '/' }
  let(:rdfizer) { instance_double(TAO::RDFizer) }

  before do
    allow(TAO::RDFizer).to receive(:new).with(:spans).and_return(rdfizer)
    allow(rdfizer).to receive(:rdfize).and_return('')
  end

  after do
    FileUtils.remove_entry(rdf_dir) if File.exist?(rdf_dir)
  end

  def create_project_doc(project)
    doc = create(:doc)
    create(:project_doc, project: project, doc: doc)
    doc
  end

  describe 'find_each usage' do
    it 'uses find_each to iterate docs in batches' do
      docs_relation = project.docs
      allow(project).to receive(:docs).and_return(docs_relation)

      expect(docs_relation).to receive(:find_each).and_call_original

      project.create_spans_RDF(nil, rdf_loc)
    end

    it 'yields sequential indices starting from 0' do
      3.times { create_project_doc(project) }

      allow_any_instance_of(Doc).to receive(:get_denotations_hash_all).and_return({ denotations: [], target: 'http://example.org' })

      yielded_indices = []
      project.create_spans_RDF(nil, rdf_loc) do |i, _doc, _message|
        yielded_indices << i
      end

      expect(yielded_indices).to eq([0, 1, 2])
    end
  end

  describe 'yielding progress' do
    it 'yields index, doc, and nil for each doc' do
      docs = 3.times.map { create_project_doc(project) }

      allow_any_instance_of(Doc).to receive(:get_denotations_hash_all).and_return({ denotations: [], target: 'http://example.org' })

      yielded = []
      project.create_spans_RDF(nil, rdf_loc) do |i, doc, message|
        yielded << [i, doc.class.name, message]
      end

      expect(yielded.length).to eq(3)
      yielded.each_with_index do |(idx, klass, msg), expected_idx|
        expect(idx).to eq(expected_idx)
        expect(klass).to eq('Doc')
        expect(msg).to be_nil
      end
    end
  end

  describe 'error handling' do
    it 'yields error message and continues when block given' do
      create_project_doc(project)

      allow_any_instance_of(Doc).to receive(:get_denotations_hash_all).and_raise(RuntimeError, 'span error')

      yielded = []
      project.create_spans_RDF(nil, rdf_loc) do |i, _doc, message|
        yielded << [i, message]
      end

      expect(yielded.length).to eq(1)
      expect(yielded.first[1]).to include('span error')
    end

    it 'increments index even after an error' do
      2.times { create_project_doc(project) }

      call_count = 0
      allow_any_instance_of(Doc).to receive(:get_denotations_hash_all) do
        call_count += 1
        raise RuntimeError, 'error' if call_count == 1
        { denotations: [], target: 'http://example.org' }
      end

      yielded_indices = []
      project.create_spans_RDF(nil, rdf_loc) do |i, _doc, _message|
        yielded_indices << i
      end

      expect(yielded_indices).to eq([0, 1])
    end
  end

  describe 'output file' do
    it 'writes a trig file with prefixes and graph blocks' do
      create_project_doc(project)

      allow_any_instance_of(Doc).to receive(:get_denotations_hash_all).and_return({ denotations: [], target: 'http://example.org' })
      allow(rdfizer).to receive(:rdfize).and_return("@prefix ex: <http://example.org/> .\n")

      project.create_spans_RDF(nil, rdf_loc)

      filename = project.send(:spans_rdf_filename)
      content = File.read(File.join(rdf_loc, filename))

      expect(content).to include('GRAPH')
      expect(content).to include('oa:Annotation')
    end
  end
end
