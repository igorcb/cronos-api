require 'rails_helper'

RSpec.describe UploadServiceJob, type: :job do
  describe '#perform' do
    let(:file_path) { 'spec/fixtures/files/tasks.xlsx' }
    let(:upload_id) { 1 }

    it 'calls UploadService with the correct arguments' do
      upload = instance_double(Upload)
      allow(Upload).to receive(:find).with(upload_id).and_return(upload)

      service = instance_double(UploadService)
      allow(UploadService).to receive(:new).with(file_path, upload).and_return(service)

      allow(service).to receive(:call)

      described_class.new.perform(file_path, upload_id)

      expect(Upload).to have_received(:find).with(upload_id)
      expect(UploadService).to have_received(:new).with(file_path, upload)
      expect(service).to have_received(:call)
    end
  end
end