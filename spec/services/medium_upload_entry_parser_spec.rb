# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediumUploadEntryParser do
  def build_zip_entry(filename, data = '')
    zip_file = Tempfile.new(['test', '.zip'])
    zip_file.close
    Zip::OutputStream.open(zip_file.path) do |zip|
      zip.put_next_entry(filename)
      zip.write(data)
    end
    Zip::File.open(zip_file.path) { |zip| zip.entries.first }
  end

  describe '.call' do
    context 'with a valid filename' do
      it 'returns a MediumUploadEntry with the parsed attributes' do
        entry = build_zip_entry('PMC-12345.png')

        upload_entry = described_class.call(entry)

        expect(upload_entry).to have_attributes(
          filename: 'PMC-12345.png',
          ext: '.png',
          sourcedb: 'PMC',
          sourceid: '12345',
          media_type: :image,
          content_type: 'image/png'
        )
      end
    end

    context 'without an extension' do
      it 'raises a ValidationError' do
        entry = build_zip_entry('PMC-12345')

        expect { described_class.call(entry) }.to raise_error(MediumUploadEntry::ValidationError, /no extension/)
      end
    end

    context 'with an unsupported extension' do
      it 'raises a ValidationError' do
        entry = build_zip_entry('PMC-12345.txt')

        expect { described_class.call(entry) }.to raise_error(MediumUploadEntry::ValidationError, /unsupported extension/)
      end
    end

    context 'with an invalid filename format' do
      it 'raises a ValidationError for a filename with spaces' do
        entry = build_zip_entry('my file-001.png')

        expect { described_class.call(entry) }.to raise_error(MediumUploadEntry::ValidationError, /sourcedb-sourceid/)
      end

      it 'raises a ValidationError for a filename with multiple hyphens' do
        entry = build_zip_entry('PMC-sub-12345.png')

        expect { described_class.call(entry) }.to raise_error(MediumUploadEntry::ValidationError, /sourcedb-sourceid/)
      end

      it 'raises a ValidationError for a filename without a hyphen' do
        entry = build_zip_entry('PMC12345.png')

        expect { described_class.call(entry) }.to raise_error(MediumUploadEntry::ValidationError, /sourcedb-sourceid/)
      end
    end
  end
end
