# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageCaptionService do
  let(:image_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_image.png').to_s }

  describe '#call' do
    context 'when Ollama returns a caption' do
      before do
        mock_response = double('response', content: 'A chest X-ray image.')
        mock_file = double('file')
        mock_ctx = double('ctx')
        allow(mock_ctx).to receive(:local_file).with(image_path).and_return(mock_file)
        allow(mock_ctx).to receive(:talk).and_return(mock_response)
        allow(LLM::Context).to receive(:new).and_return(mock_ctx)
        allow(LLM).to receive(:ollama).and_return(double('llm', default_model: nil))
      end

      it 'returns the generated caption' do
        result = described_class.new(image_path).call
        expect(result).to eq('A chest X-ray image.')
      end
    end

    context 'when Ollama is not available' do
      before do
        allow(LLM).to receive(:ollama).and_raise(StandardError, 'Connection refused')
      end

      it 'raises an error' do
        expect {
          described_class.new(image_path).call
        }.to raise_error(StandardError, 'Connection refused')
      end
    end
  end
end
