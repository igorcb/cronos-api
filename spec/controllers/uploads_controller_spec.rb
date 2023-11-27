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
      allow_any_instance_of(Upload).to receive(:save).and_return(false)

      post :create, params: { file: excel_file }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq({ 'error' => 'Failed to save upload record.' })
    end
  end
end
