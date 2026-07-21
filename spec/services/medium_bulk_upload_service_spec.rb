# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumBulkUploadService do
  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:png_data) { File.binread(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')) }
  let(:mp4_data) { File.binread(Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4')) }
  let(:mp3_data) { File.binread(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')) }

  def build_zip(entries)
    Tempfile.new(['test', '.zip']).tap do |zip_file|
      zip_file.close
      Zip::OutputStream.open(zip_file.path) do |zip|
        entries.each do |name, data|
          zip.put_next_entry(name)
          zip.write(data || '')
        end
      end
    end
  end

  def collect_results(service)
    [].tap { |results| service.call { |r| results << r } }
  end

  describe '#total_count' do
    it 'returns the number of non-skippable entries' do
      zip_file = build_zip({
        'PMC-12345.png' => png_data,
        'PMC-67890.png' => png_data,
        '.DS_Store' => '',
        '__MACOSX/._PMC-12345.png' => ''
      })
      expect(described_class.new(zip_file.path, user).total_count).to eq(2)
    end
  end

  describe '#call' do
    context 'with valid image files' do
      let(:zip_file) { build_zip({ 'PMC-12345.png' => png_data }) }

      it 'creates a Medium' do
        expect {
          described_class.new(zip_file.path, user).call
        }.to change(Medium, :count).by(1)
      end

      it 'sets sourcedb and sourceid correctly' do
        described_class.new(zip_file.path, user).call
        medium = Medium.find_by(sourcedb: 'PMC', sourceid: '12345')
        expect(medium).to be_present
      end

      it 'yields a success result' do
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.count { |r| r.status == :success }).to eq(1)
        expect(results.none? { |r| r.status == :error }).to be true
      end
    end

    context 'with valid video and audio files' do
      let(:zip_file) do
        build_zip({
          'PMC-11111.mp4' => mp4_data,
          'PMC-22222.mp3' => mp3_data
        })
      end

      it 'creates media with the correct media_type and content_type' do
        expect {
          described_class.new(zip_file.path, user).call
        }.to change(Medium, :count).by(2)

        video = Medium.find_by(sourcedb: 'PMC', sourceid: '11111')
        expect(video).to have_attributes(media_type: 'video', content_type: 'video/mp4')

        audio = Medium.find_by(sourcedb: 'PMC', sourceid: '22222')
        expect(audio).to have_attributes(media_type: 'audio', content_type: 'audio/mpeg')
      end
    end

    context 'with macOS metadata files' do
      let(:zip_file) do
        build_zip({
          '.DS_Store' => '',
          '__MACOSX/._PMC-12345.png' => '',
          'PMC-12345.png' => png_data
        })
      end

      it 'skips .DS_Store and __MACOSX files' do
        results = collect_results(described_class.new(zip_file.path, user))
        expect(Medium.count).to eq(1)
        expect(results.count { |r| r.status == :success }).to eq(1)
        expect(results.none? { |r| r.status == :error }).to be true
      end
    end

    context 'with a file without extension' do
      let(:zip_file) { build_zip({ 'PMC-12345' => '' }) }

      it 'yields an error result' do
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.first.status).to eq(:error)
        expect(results.first.message).to include('no extension')
      end
    end

    context 'with an unsupported extension' do
      let(:zip_file) { build_zip({ 'PMC-12345.txt' => '' }) }

      it 'yields an error result' do
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.first.status).to eq(:error)
        expect(results.first.message).to include('unsupported extension')
      end
    end

    context 'with invalid filename format' do
      it 'yields an error for filename with spaces' do
        zip_file = build_zip({ 'my file-001.png' => png_data })
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.first.status).to eq(:error)
        expect(results.first.message).to include('sourcedb-sourceid')
      end

      it 'yields an error for filename with multiple hyphens' do
        zip_file = build_zip({ 'PMC-sub-12345.png' => png_data })
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.first.status).to eq(:error)
        expect(results.first.message).to include('sourcedb-sourceid')
      end

      it 'yields an error for filename without hyphen' do
        zip_file = build_zip({ 'PMC12345.png' => png_data })
        results = collect_results(described_class.new(zip_file.path, user))
        expect(results.first.status).to eq(:error)
        expect(results.first.message).to include('sourcedb-sourceid')
      end
    end

    context 'when an unexpected error occurs while creating a Medium' do
      let(:zip_file) { build_zip({ 'PMC-12345.png' => png_data }) }

      it 'propagates the error instead of treating it as a validation failure' do
        allow_any_instance_of(MediumUploadEntry).to receive(:create_medium).and_raise(RuntimeError, 'unexpected bug')

        expect {
          described_class.new(zip_file.path, user).call
        }.to raise_error(RuntimeError, 'unexpected bug')
      end
    end

    context 'with an invalid ZIP file' do
      let(:zip_file) do
        Tempfile.new(['bad', '.zip']).tap do |f|
          f.write('not a zip file')
          f.close
        end
      end

      it 'raises ArgumentError' do
        expect {
          described_class.new(zip_file.path, user).call
        }.to raise_error(ArgumentError, /Invalid ZIP file/)
      end
    end
  end
end
