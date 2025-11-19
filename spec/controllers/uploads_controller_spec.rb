require 'rails_helper'
require 'tempfile'

RSpec.describe UploadsController, type: :controller do
  describe 'GET #new' do
    it 'returns success status' do
      get :new

      expect(response).to be_successful
    end
  end

  describe 'GET #index' do
    it 'lists uploads with mapped fields' do
      u1 = create(:upload, file_name: 'a.xlsx', status: :completed, total_lines: 2, success_count: 2, error_count: 0, error_messages: '')
      u2 = create(:upload, file_name: 'b.xlsx', status: :failed, total_lines: 3, success_count: 1, error_count: 2, error_messages: "x\ny")

      get :index

      expect(response).to be_successful
      body = response.parsed_body
      expect(body.size).to eq(2)
      expect(body.first['id']).to eq(u2.id)
      expect(body.first['fileName']).to eq('b.xlsx')
      expect(body.first['status']).to eq('failed')
      expect(body.first['totalLines']).to eq(3)
      expect(body.first['successCount']).to eq(1)
      expect(body.first['errorCount']).to eq(2)
      expect(body.first['processedCount']).to eq(3)
    end
  end

  describe 'GET #show' do
    it 'returns details for a single upload' do
      u = create(:upload, file_name: 'c.xlsx', status: :processing, total_lines: 5, success_count: 3, error_count: 2, error_messages: 'e1\ne2')

      get :show, params: { id: u.id }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(u.id)
      expect(body['fileName']).to eq('c.xlsx')
      expect(body['status']).to eq('processing')
      expect(body['totalLines']).to eq(5)
      expect(body['successCount']).to eq(3)
      expect(body['errorCount']).to eq(2)
      expect(body['processedCount']).to eq(5)
    end
  end

  describe 'POST #create' do
    let(:excel_file) { fixture_file_upload('spec/fixtures/files/tasks.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

    it 'creates a new upload record and starts processing for Excel file (async por padrão)' do
      expect {
        post :create, params: { file: excel_file }
      }.to change(Upload, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(response.headers['X-Upload-Id']).to be_present
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

  describe 'POST #create com UPLOAD_SYNC=1' do
    let(:excel_file) { fixture_file_upload('spec/fixtures/files/tasks.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

    around do |example|
      original = ENV['UPLOAD_SYNC']
      ENV['UPLOAD_SYNC'] = '1'
      example.run
      ENV['UPLOAD_SYNC'] = original
    end

    it 'processa de forma síncrona e seta header X-Upload-Id' do
      post :create, params: { file: excel_file }
      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
    end
  end
end
