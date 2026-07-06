# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaBulkUploadJob, type: :job do
  let(:user) { create(:user) }

  def setup_job_record(user)
    job_record = create(:job, organization: user)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:increment!)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(MediaBulkUploadJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  def stub_service(total_count:, results: [])
    service = instance_double(MediumBulkUploadService, total_count: total_count)
    expectation = allow(service).to receive(:call)
    results.each { |result| expectation.and_yield(result) }
    allow(MediumBulkUploadService).to receive(:new).and_return(service)
    service
  end

  def result(status:, filename: 'PMC-1.png', message: nil)
    MediumBulkUploadService::Result.new(filename:, status:, message:)
  end

  describe '.enqueue' do
    let(:tempfile) do
      Tempfile.new(['upload', '.zip']).tap do |f|
        f.write('dummy zip content')
        f.close
      end
    end

    it 'enqueues a MediaBulkUploadJob for the user' do
      expect {
        MediaBulkUploadJob.enqueue(user, tempfile)
      }.to have_enqueued_job(MediaBulkUploadJob).with(user, instance_of(String))
    end

    it 'moves the uploaded file under tmp/media_bulk_uploads and removes the original' do
      original_path = tempfile.path

      enqueued_zip_path = nil
      allow(MediaBulkUploadJob).to receive(:perform_later) do |_user, zip_path|
        enqueued_zip_path = zip_path
      end

      MediaBulkUploadJob.enqueue(user, tempfile)

      expect(enqueued_zip_path).to match(%r{tmp/media_bulk_uploads/.+\.zip\z})
      expect(File.exist?(enqueued_zip_path)).to be true
      expect(File.exist?(original_path)).to be false
    ensure
      FileUtils.rm_f(enqueued_zip_path)
    end
  end

  describe '#perform' do
    let(:zip_path) { Rails.root.join('tmp', "media_bulk_upload_job_spec_#{SecureRandom.hex(4)}.zip").to_s }

    before { FileUtils.touch(zip_path) }

    it 'initializes progress tracking with the service total_count' do
      job_record = setup_job_record(user)
      stub_service(total_count: 3)

      MediaBulkUploadJob.perform_now(user, zip_path)

      expect(job_record).to have_received(:update_attribute).with(:num_items, 3)
      expect(job_record).to have_received(:update_attribute).with(:num_dones, 0)
    end

    it 'increments progress for every yielded result, success or error' do
      job_record = setup_job_record(user)
      stub_service(total_count: 2, results: [result(status: :success), result(status: :error, message: 'boom')])

      MediaBulkUploadJob.perform_now(user, zip_path)

      expect(job_record).to have_received(:increment!).with(:num_dones, 1).twice
    end

    it 'records a job message only for error results' do
      job_record = setup_job_record(user)
      stub_service(total_count: 2, results: [result(status: :success), result(status: :error, message: 'boom')])

      MediaBulkUploadJob.perform_now(user, zip_path)

      expect(job_record).to have_received(:add_message).with(sourcedb: '*', sourceid: '*', body: 'boom').once
    end

    it 'stops incrementing progress once the job is suspended' do
      job_record = setup_job_record(user)
      stub_service(total_count: 2, results: [result(status: :success), result(status: :success)])

      call_count = 0
      allow_any_instance_of(MediaBulkUploadJob).to receive(:check_suspend_flag) do
        call_count += 1
        raise Exceptions::JobSuspendError if call_count == 1
      end

      MediaBulkUploadJob.perform_now(user, zip_path)

      expect(job_record).to have_received(:increment!).with(:num_dones, 1).once
    end

    it 'removes the zip file after processing completes' do
      setup_job_record(user)
      stub_service(total_count: 0)

      MediaBulkUploadJob.perform_now(user, zip_path)

      expect(File.exist?(zip_path)).to be false
    end

    it 'removes the zip file even when the service raises an error' do
      setup_job_record(user)
      service = instance_double(MediumBulkUploadService, total_count: 0)
      allow(service).to receive(:call).and_raise(ArgumentError, 'Invalid ZIP file')
      allow(MediumBulkUploadService).to receive(:new).and_return(service)

      expect { MediaBulkUploadJob.perform_now(user, zip_path) }.not_to raise_error

      expect(File.exist?(zip_path)).to be false
    end
  end

  describe '#job_name' do
    it 'returns a descriptive name' do
      job = MediaBulkUploadJob.new(user, 'dummy_path.zip')
      expect(job.job_name).to eq('Media Bulk Upload')
    end
  end
end
