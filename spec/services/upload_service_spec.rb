require 'rails_helper'

RSpec.describe UploadService do
  describe '#call' do
    let(:file_path) { 'spec/fixtures/files/tasks.xlsx' }
    let(:upload_id) { 1 }

    it 'processes the Excel file and updates the upload status' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas')
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('completed')
      expect(upload.total_lines).to eq(3)
    end

    it 'handles errors and updates the upload status accordingly' do
      upload = create(:upload, id: upload_id, status: :processing)

      allow(Roo::Excelx).to receive(:new).and_raise(StandardError.new('Error message'))

      service = described_class.new(file_path, upload_id)
      service.call

      upload.reload
      expect(upload.status).to eq('failed')
      expect(upload.error_messages).to eq('Error message')
    end

    it 'handles case where company does not exist' do
      upload = create(:upload, id: upload_id, status: :processing)
      Company.where(name: 'NobeSistemas').destroy_all
      company = create(:company, name: 'Example Company')
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('failed')
      expect(upload.error_messages).to eq('You cannot call create unless the parent is saved')
    end

    it 'handles case where software does not exist' do
      upload = create(:upload, id: upload_id, status: :processing)
      create(:company, name: 'NobeSistemas')
      Software.where(name: 'Almoxarifado').destroy_all

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('failed')
      expect(upload.error_messages).to eq('You cannot call create unless the parent is saved')
    end

    describe '#task_item_create' do
      it 'does not create a task item if already present' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas')
        software = Software.create(company:, name: 'Almoxarifado')

        task = Task.create(company:, software:, code: '123', name: 'Task example', date_opened: '01/09/2023', status: 'opened')
        TaskItem.create(task:, date_start: '2023-01-01', hour_start: '12:00', status: 'pending')

        service.instance_variable_set(:@company_id, company.id)
        service.instance_variable_set(:@software_id, software.id)
        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, '2023-01-01')
        service.instance_variable_set(:@hour_start, '12:00')
        service.instance_variable_set(:@status, 'pending')

        service.send(:task_item_create)

        expect(task.task_items.count).to eq(1)
      end

      it 'creates a task item if task present' do
        create(:upload, id: upload_id, status: :processing)
        file_path = 'example.xlsx'

        company = Company.create(name: 'NobeSistemas')
        software = Software.create(company:, name: 'Almoxarifado')
        code = '123'
        Task.create(company:, software:, code: '123', name: 'Task example', date_opened: '01/09/2023', status: 'opened')

        task = Task.where(company_id: company.id, software_id: software.id, code:).first
        service = described_class.new(file_path, upload_id)

        allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_dublicate_task)

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, '2023-01-01')
        service.instance_variable_set(:@hour_start, '12:00')
        service.instance_variable_set(:@date_end, '2023-01-01')
        service.instance_variable_set(:@hour_end, '13:00')
        service.instance_variable_set(:@status, 'pending')

        service = described_class.new(file_path, upload_id)
        service.call

        expect { service.send(:task_item_create) }.to change { TaskItem.count }.by(0)
      end
    end

    private

    def mock_excel
      mock_excel_instance = instance_double(Roo::Excelx)
      headers = ['Dia Semana', 'Data', 'Inicio', 'Fim', 'Tempo', 'Total dia', 'Projeto', 'Status', 'Horas Aprovadas', 'Atividade']
      record_one = ['Sexta', '01/09/2023', '07:12', '08:28', '01:16', '00:00', 'Almoxarifado', 'Finalizado', 'SN', '2267: Mensagens de erro ou sucesso, não estã estilizadas']
      record_two = ['Sexta', '01/09/2023', '08:29', '10:22', '01:53', '00:00', 'Almoxarifado', 'Finalizado', 'SN', '2180: Tela Solicitante - Erro no cadastro']
      record_three = ['Sexta', '01/09/2023', '10:23', '12:38', '02:15', '00:00', 'Almoxarifado', 'Finalizado', 'SN', '2254: Exclusão de Transferências - Erro no cadastro']

      allow(mock_excel_instance).to receive(:each_with_index).and_yield(headers, 0)
        .and_yield(record_one, 1)
        .and_yield(record_two, 2)
        .and_yield(record_three, 3)
      allow(Roo::Excelx).to receive(:new).and_return(mock_excel_instance)

      mock_excel_instance
    end

    def mock_excel_dublicate_task
      mock_excel_instance = instance_double(Roo::Excelx)
      headers = ['Dia Semana', 'Data', 'Inicio', 'Fim', 'Tempo', 'Total dia', 'Projeto', 'Status', 'Horas Aprovadas', 'Atividade']
      record_one = ['Sexta', '01/09/2023', '08:29', '10:22', '01:53', '00:00', 'Almoxarifado', 'Finalizado', 'SN', '2180: Tela Solicitante - Erro no cadastro']
      record_two = ['Sexta', '01/09/2023', '08:29', '10:22', '01:53', '00:00', 'Almoxarifado', 'Finalizado', 'SN', '2180: Tela Solicitante - Erro no cadastro']

      allow(mock_excel_instance).to receive(:each_with_index).and_yield(headers, 0)
        .and_yield(record_one, 1)
        .and_yield(record_two, 2)
      allow(Roo::Excelx).to receive(:new).and_return(mock_excel_instance)

      mock_excel_instance
    end
  end
end