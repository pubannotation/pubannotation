# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmbeddingService do
  let(:sample_text) { "p53 tumor suppressor protein regulates cell cycle arrest" }
  let(:sample_embedding) { Array.new(768) { rand(-1.0..1.0) } }

  describe '.generate' do
    context 'with valid text' do
      before do
        allow(described_class).to receive(:make_single_request)
          .and_return({ 'embedding' => sample_embedding })
      end

      it 'returns a 768-dimensional embedding vector' do
        result = described_class.generate(sample_text)
        expect(result).to be_an(Array)
        expect(result.size).to eq(768)
      end

      it 'truncates text longer than MAX_TEXT_LENGTH' do
        long_text = "word " * 1000  # ~5000 chars
        described_class.generate(long_text)

        expect(described_class).to have_received(:make_single_request) do |text|
          expect(text.length).to be <= EmbeddingService::MAX_TEXT_LENGTH
        end
      end
    end

    context 'with blank text' do
      it 'returns nil for nil input' do
        expect(described_class.generate(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.generate('')).to be_nil
      end

      it 'returns nil for whitespace-only string' do
        expect(described_class.generate('   ')).to be_nil
      end
    end

    context 'when service fails' do
      before do
        allow(described_class).to receive(:make_single_request).and_return(nil)
      end

      it 'returns nil on service failure' do
        expect(described_class.generate(sample_text)).to be_nil
      end
    end
  end

  describe '.generate_batch' do
    let(:texts) { ["text one", "text two", "text three"] }
    let(:batch_embeddings) { texts.map { Array.new(768) { rand(-1.0..1.0) } } }

    context 'with valid texts' do
      before do
        allow(described_class).to receive(:make_batch_request)
          .and_return({ 'embeddings' => batch_embeddings })
      end

      it 'returns embeddings for all texts' do
        result = described_class.generate_batch(texts)
        expect(result.size).to eq(3)
        expect(result.all? { |e| e.is_a?(Array) && e.size == 768 }).to be true
      end

      it 'truncates each text if needed' do
        long_texts = ["word " * 1000, "short text"]
        described_class.generate_batch(long_texts)

        expect(described_class).to have_received(:make_batch_request) do |truncated_texts|
          truncated_texts.each do |text|
            expect(text.length).to be <= EmbeddingService::MAX_TEXT_LENGTH
          end
        end
      end
    end

    context 'with empty input' do
      it 'returns empty array for nil' do
        expect(described_class.generate_batch(nil)).to eq([])
      end

      it 'returns empty array for empty array' do
        expect(described_class.generate_batch([])).to eq([])
      end
    end

    context 'when service fails' do
      before do
        allow(described_class).to receive(:make_batch_request).and_return(nil)
      end

      it 'returns array of nils matching input size' do
        result = described_class.generate_batch(texts)
        expect(result).to eq([nil, nil, nil])
      end
    end
  end

  describe '.available?' do
    it 'returns true when service responds' do
      allow(described_class).to receive(:make_single_request)
        .with('test', timeout: 5)
        .and_return({ 'embedding' => sample_embedding })

      expect(described_class.available?).to be true
    end

    it 'returns false when service fails' do
      allow(described_class).to receive(:make_single_request)
        .with('test', timeout: 5)
        .and_return(nil)

      expect(described_class.available?).to be false
    end

    it 'returns false when service raises exception' do
      allow(described_class).to receive(:make_single_request)
        .and_raise(StandardError.new('connection refused'))

      expect(described_class.available?).to be false
    end
  end

  describe '.dimensions' do
    it 'returns 768 for PubMedBERT' do
      expect(described_class.dimensions).to eq(768)
    end
  end

  describe '.cosine_similarity' do
    let(:embedding1) { [1.0, 0.0, 0.0] }
    let(:embedding2) { [1.0, 0.0, 0.0] }
    let(:orthogonal) { [0.0, 1.0, 0.0] }
    let(:opposite) { [-1.0, 0.0, 0.0] }

    it 'returns 1.0 for identical vectors' do
      expect(described_class.cosine_similarity(embedding1, embedding2)).to be_within(0.001).of(1.0)
    end

    it 'returns 0.0 for orthogonal vectors' do
      expect(described_class.cosine_similarity(embedding1, orthogonal)).to be_within(0.001).of(0.0)
    end

    it 'returns -1.0 for opposite vectors' do
      expect(described_class.cosine_similarity(embedding1, opposite)).to be_within(0.001).of(-1.0)
    end

    it 'returns nil if either embedding is nil' do
      expect(described_class.cosine_similarity(nil, embedding1)).to be_nil
      expect(described_class.cosine_similarity(embedding1, nil)).to be_nil
    end

    it 'returns nil if embeddings have different dimensions' do
      expect(described_class.cosine_similarity([1, 2], [1, 2, 3])).to be_nil
    end
  end

  describe 'text truncation' do
    it 'preserves text under MAX_TEXT_LENGTH' do
      short_text = "Short biomedical text about proteins."
      truncated = described_class.send(:truncate_text, short_text)
      expect(truncated).to eq(short_text)
    end

    it 'truncates at word boundary when possible' do
      # Create text just over the limit
      words = "word " * 700  # ~3500 chars
      truncated = described_class.send(:truncate_text, words)

      expect(truncated.length).to be <= EmbeddingService::MAX_TEXT_LENGTH
      expect(truncated).not_to end_with(' ')  # Should end at word boundary
    end
  end
end
