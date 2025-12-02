require 'rails_helper'

RSpec.describe UploadJsonServiceJob, type: :job do
  it 'chama UploadJsonService com argumentos fornecidos' do
    service = instance_double(UploadJsonService, call: true)
    allow(UploadJsonService).to receive(:new).and_return(service)

    described_class.new.perform([{ codeName: '1: X' }], 456)

    expect(UploadJsonService).to have_received(:new).with([{ codeName: '1: X' }], 456)
    expect(service).to have_received(:call)
  end
end

