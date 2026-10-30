# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RdfIndexStatus do
  let(:target) { 'https://pubannotation.org/docs/sourcedb/PMC/sourceid/123' }
  let(:endpoint) { double('endpoint') }

  it 'reads the generation timestamp from the document graph' do
    result = double('result', body: { 'results' => { 'bindings' => [{ 'o' => { 'value' => '2026-10-29T01:02:03Z' } }] } })
    expect(endpoint).to receive(:query).with(
      Rails.application.config.ep_database,
      "select ?o where {<#{target}> <http://www.w3.org/ns/prov#generatedAtTime> ?o}"
    ).and_return(result)

    expect(described_class.last_indexed_at(target, endpoint)).to eq(DateTime.iso8601('2026-10-29T01:02:03Z'))
  end

  it 'returns nil when the endpoint has no generation timestamp' do
    allow(endpoint).to receive(:query).and_return(double('result', body: { 'results' => { 'bindings' => [] } }))

    expect(described_class.last_indexed_at(target, endpoint)).to be_nil
  end

  it 'uses the configured endpoint when none is supplied' do
    expect(described_class).to receive(:stardog).with(
      Rails.application.config.ep_url,
      user: Rails.application.config.ep_user,
      password: Rails.application.config.ep_password
    ).and_return(endpoint)
    allow(endpoint).to receive(:query).and_return(double('result', body: { 'results' => { 'bindings' => [] } }))

    expect(described_class.last_indexed_at(target)).to be_nil
  end

  it 'returns nil when the generation timestamp is invalid' do
    result = double('result', body: { 'results' => { 'bindings' => [{ 'o' => { 'value' => 'invalid' } }] } })
    allow(endpoint).to receive(:query).and_return(result)

    expect(described_class.last_indexed_at(target, endpoint)).to be_nil
  end

  it 'propagates endpoint query failures' do
    allow(endpoint).to receive(:query).and_raise(RuntimeError, 'endpoint unavailable')

    expect { described_class.last_indexed_at(target, endpoint) }.to raise_error(RuntimeError, 'endpoint unavailable')
  end

end
