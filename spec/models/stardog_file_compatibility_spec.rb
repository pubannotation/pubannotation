# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe Stardog::Connection do
  let(:connection) { stardog('http://localhost/') }
  let(:graph_uri) { 'urn:test:graph' }
  let(:graph_params) { {'graph-uri' => graph_uri} }
  let(:success) { Stardog::StardogResponse.new(200, '') }

  before do
    expect(connection).to receive(:http_request).with('POST', 'test/transaction/begin', 'text/plain', '').ordered
      .and_return(Stardog::StardogResponse.new(200, 'tx1'))
  end

  it 'adds inline RDF and commits the transaction' do
    rdf = '<urn:subject> <urn:predicate> <urn:object> .'
    expect(connection).to receive(:http_request).with('POST', 'test/tx1/add', '*/*', graph_params, rdf, false, 'text/turtle', nil).ordered
      .and_return(success)
    expect(connection).to receive(:http_request).with('POST', 'test/transaction/commit/tx1', 'text/plain', '').ordered
      .and_return(success)

    expect(connection.add('test', rdf, graph_uri, 'text/turtle')).to eq(0)
  end

  it 'reads an update from a file and commits the transaction' do
    update = 'DELETE WHERE { ?s ?p ?o }'
    expect(connection).to receive(:http_request).with('POST', 'test/tx1/update', '*/*', graph_params, update, false, 'application/sparql-update', nil).ordered
      .and_return(success)
    expect(connection).to receive(:http_request).with('POST', 'test/transaction/commit/tx1', 'text/plain', '').ordered
      .and_return(success)

    Tempfile.create('stardog-update') do |file|
      file.write(update)
      file.flush
      expect(connection.update('test', file.path, graph_uri)).to eq(0)
    end
  end

  it 'fetches RDF from a URL before adding it' do
    url = 'https://example.test/data.ttl'
    rdf = '<urn:subject> <urn:predicate> <urn:object> .'
    expect(connection).to receive(:http_request).with('GET', url, 'text/turtle', {}, nil, false).ordered
      .and_return(Stardog::StardogResponse.new(200, rdf))
    expect(connection).to receive(:http_request).with('POST', 'test/tx1/add', '*/*', nil, rdf, false, 'text/turtle', nil).ordered
      .and_return(success)
    expect(connection).to receive(:http_request).with('POST', 'test/transaction/commit/tx1', 'text/plain', '').ordered
      .and_return(success)

    expect(connection.add('test', url, nil, 'text/turtle')).to eq(0)
  end
end
