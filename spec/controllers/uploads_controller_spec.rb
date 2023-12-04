require 'rails_helper'
require 'tempfile'

RSpec.describe UploadsController, type: :controller do
  describe 'GET #new' do
    it 'returns success status' do
      get :new

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    let(:excel_file) { fixture_file_upload('spec/fixtures/files/tasks.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

    it 'creates a new upload record and starts processing for Excel file' do
      expect {
        post :create, params: { file: excel_file }
      }.to change(Upload, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
    end

    it 'returns an error if upload record cannot be saved' do
      upload_instance = instance_double(Upload)
      allow(upload_instance).to receive(:save).and_return(false)
      allow(Upload).to receive(:new).and_return(upload_instance)

      post :create, params: { file: excel_file }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({ 'error' => 'Failed to save upload record.' })
    end
  end
end
