# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageCaptionService do
  let(:image_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_image.png').to_s }

  describe '#call' do
    let(:mock_http)     { instance_double(Net::HTTP) }
    let(:mock_request)  { instance_double(Net::HTTP::Post) }
    let(:mock_response) { instance_double(Net::HTTPResponse) }

    before do
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
    end

    context 'when Ollama returns a caption' do
      before do
        chunk = [{message: {content: 'A chest '}, done: false},
                 {message: {content: 'X-ray image.'}, done: true}].map(&:to_json).join("\n")
        allow(mock_http).to receive(:request).with(mock_request).and_yield(mock_response)
        allow(mock_response).to receive(:code).and_return('200')
        allow(mock_response).to receive(:read_body).and_yield(chunk)
      end

      it 'returns the generated caption' do
        result = described_class.new(image_path).call
        expect(result).to eq('A chest X-ray image.')
      end
    end

    context 'when a JSON line is split across read_body chunks' do
      before do
        full_line = {message: {content: 'A chest X-ray image.'}, done: true}.to_json
        split_at = full_line.length / 2

        allow(mock_http).to receive(:request).with(mock_request).and_yield(mock_response)
        allow(mock_response).to receive(:code).and_return('200')
        allow(mock_response).to receive(:read_body)
          .and_yield(full_line[0...split_at])
          .and_yield(full_line[split_at..] + "\n")
      end

      it 'buffers the partial chunks and parses the complete line' do
        result = described_class.new(image_path).call
        expect(result).to eq('A chest X-ray image.')
      end
    end

    context 'when Ollama responds with a non-2xx status' do
      before do
        allow(mock_http).to receive(:request).with(mock_request).and_yield(mock_response)
        allow(mock_response).to receive(:code).and_return('500')
      end

      it 'raises an error' do
        expect {
          described_class.new(image_path).call
        }.to raise_error('Ollama request failed (status 500)')
      end
    end

    context 'when Ollama is not available' do
      before do
        allow(mock_http).to receive(:request).and_raise(StandardError, 'Connection refused')
      end

      it 'raises an error' do
        expect {
          described_class.new(image_path).call
        }.to raise_error(StandardError, 'Connection refused')
      end
    end
  end
end
