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
      create(:upload, file_name: 'a.xlsx', status: :completed, total_lines: 2, success_count: 2, error_count: 0, error_messages: '')
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

    it 'processa Excel com sync=1 chamando UploadService e seta header' do
      service_instance = instance_double(UploadService, call: true)
      allow(UploadService).to receive(:new).and_return(service_instance)

      post :create, params: { file: excel_file, sync: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end
  end

  describe 'POST #create com JSON' do
    it 'cria upload e processa JSON rows (async por padrão)' do
      payload = {
        rows: [
          { codeName: '2180: Tela Solicitante - Erro no cadastro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '08:29', hourEnd: '10:22', status: 'Finalizado' },
          { codeName: '2267: Mensagens de erro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '10:23', hourEnd: '12:38', status: 'Pendência' },
        ],
      }

      expect {
        post :create, params: payload
      }.to change(Upload, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(response.headers['X-Upload-Id']).to be_present
    end

    it 'retorna erro quando payload inválido' do
      post :create, params: { rows: 'invalid' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({ 'error' => 'Invalid JSON payload. Expected array in rows.' })
    end

    it 'retorna erro quando falha salvar upload Excel' do
      file = fixture_file_upload('spec/fixtures/files/tasks.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      allow(Upload).to receive(:new).and_return(instance_double(Upload, save: false))
      post :create, params: { file: file }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({ 'error' => 'Failed to save upload record.' })
    end

    it 'retorna erro quando falha salvar upload JSON' do
      rows = [{ codeName: 'x', software: 'y', date: '01/01/2025', hourStart: '08:00', hourEnd: '09:00', status: 'Finalizado' }]
      allow(Upload).to receive(:new).and_return(instance_double(Upload, save: false))
      post :create, params: { rows: rows }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq({ 'error' => 'Failed to save upload record.' })
    end

    it 'processa JSON com sync=1 chamando UploadJsonService e seta header' do
      rows = [
        { codeName: '2180: Tela Solicitante - Erro no cadastro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '08:29', hourEnd: '10:22', status: 'Finalizado' },
      ]
      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      post :create, params: { rows:, sync: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end

    it 'processa Excel no modo async e seta header' do
      file = fixture_file_upload('spec/fixtures/files/tasks.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      allow(UploadServiceJob).to receive(:perform_later)
      post :create, params: { file: file, sync: '0' }
      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadServiceJob).to have_received(:perform_later)
    end

    it 'normaliza rows quando são ActionController::Parameters (to_unsafe_h)' do
      payload = {
        rows: [
          ActionController::Parameters.new({ codeName: '2180: Tela', software: 'Almoxarifado', date: '01/09/2023', hourStart: '08:29', hourEnd: '10:22', status: 'Finalizado' }).permit!,
        ],
        sync: '1',
      }

      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      post :create, params: payload

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end

    it 'aceita payload em _json e processa via UploadJsonService' do
      rows = [
        { codeName: '2267: Mensagens', software: 'Almoxarifado', date: '01/09/2023', hourStart: '10:23', hourEnd: '12:38', status: 'Pendência' },
      ]
      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      post :create, params: { _json: rows, sync: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end

    it 'processa JSON via items key e sync=1' do
      items = [
        { codeName: '3001: Via items', software: 'Almoxarifado', date: '02/09/2023', hourStart: '09:00', hourEnd: '10:00', status: 'Finalizado' },
      ]
      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      post :create, params: { items:, sync: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end

    it 'processa JSON com UPLOAD_SYNC=1 (ENV) e rows' do
      rows = [
        { codeName: '3002: Via ENV', software: 'Almoxarifado', date: '02/09/2023', hourStart: '09:00', hourEnd: '10:00', status: 'Finalizado' },
      ]
      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      original = ENV['UPLOAD_SYNC']
      ENV['UPLOAD_SYNC'] = '1'
      post :create, params: { rows: rows }
      ENV['UPLOAD_SYNC'] = original

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
    end

    it 'processa JSON via data key e sync=1' do
      data = [
        { codeName: '3003: Via data', software: 'Almoxarifado', date: '02/09/2023', hourStart: '09:00', hourEnd: '10:00', status: 'Finalizado' },
      ]
      service_instance = instance_double(UploadJsonService, call: true)
      allow(UploadJsonService).to receive(:new).and_return(service_instance)

      post :create, params: { data:, sync: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Upload-Id']).to be_present
      expect(response.parsed_body).to eq({ 'message' => 'File processing started successfully.' })
      expect(UploadJsonService).to have_received(:new)
      expect(service_instance).to have_received(:call)
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
