require 'rails_helper'

RSpec.describe UploadServiceJob, type: :job do
  describe '#perform' do
    let(:file_path) { 'spec/fixtures/files/tasks.xlsx' }
    let(:upload_id) { 1 }

    it 'calls UploadService with the correct arguments' do
      upload_service_instance = instance_double(UploadService, call: true)
      allow(UploadService).to receive(:new).and_return(upload_service_instance)

      described_class.new.perform(file_path, upload_id)

      expect(UploadService).to have_received(:new).with(file_path, upload_id)
      expect(upload_service_instance).to have_received(:call)
    end
  end
end