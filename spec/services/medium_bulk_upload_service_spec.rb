# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumBulkUploadService do
  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:png_data) { File.binread(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')) }

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

  describe '#call' do
    context 'with valid image files' do
      let(:zip_file) { build_zip({ 'PMC-12345.png' => png_data }) }

      it 'creates a Medium' do
        expect {
          described_class.new(zip_file, user).call
        }.to change(Medium, :count).by(1)
      end

      it 'sets sourcedb and sourceid correctly' do
        described_class.new(zip_file, user).call
        medium = Medium.find_by(sourcedb: 'PMC', sourceid: '12345')
        expect(medium).to be_present
      end

      it 'reports success' do
        service = described_class.new(zip_file, user)
        service.call
        expect(service.successes).to include('PMC-12345.png')
        expect(service.errors).to be_empty
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
        service = described_class.new(zip_file, user)
        service.call
        expect(Medium.count).to eq(1)
        expect(service.successes).to eq(['PMC-12345.png'])
      end
    end

    context 'with a file without extension' do
      let(:zip_file) { build_zip({ 'PMC-12345' => '' }) }

      it 'reports an error' do
        service = described_class.new(zip_file, user)
        service.call
        expect(service.errors.first).to include('no extension')
      end
    end

    context 'with an unsupported extension' do
      let(:zip_file) { build_zip({ 'PMC-12345.txt' => '' }) }

      it 'reports an error' do
        service = described_class.new(zip_file, user)
        service.call
        expect(service.errors.first).to include('unsupported extension')
      end
    end

    context 'with invalid filename format' do
      it 'reports error for filename with spaces' do
        zip_file = build_zip({ 'my file-001.png' => png_data })
        service = described_class.new(zip_file, user)
        service.call
        expect(service.errors.first).to include('sourcedb-sourceid')
      end

      it 'reports error for filename with multiple hyphens' do
        zip_file = build_zip({ 'PMC-sub-12345.png' => png_data })
        service = described_class.new(zip_file, user)
        service.call
        expect(service.errors.first).to include('sourcedb-sourceid')
      end

      it 'reports error for filename without hyphen' do
        zip_file = build_zip({ 'PMC12345.png' => png_data })
        service = described_class.new(zip_file, user)
        service.call
        expect(service.errors.first).to include('sourcedb-sourceid')
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
          described_class.new(zip_file, user).call
        }.to raise_error(ArgumentError, /Invalid ZIP file/)
      end
    end
  end
end
