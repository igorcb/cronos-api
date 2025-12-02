require 'rails_helper'

RSpec.describe UploadServiceJob, type: :job do
  it 'chama UploadService com argumentos fornecidos' do
    service = instance_double(UploadService, call: true)
    allow(UploadService).to receive(:new).and_return(service)

    described_class.new.perform('tmp/file.xlsx', 123)

    expect(UploadService).to have_received(:new).with('tmp/file.xlsx', 123)
    expect(service).to have_received(:call)
  end
end

