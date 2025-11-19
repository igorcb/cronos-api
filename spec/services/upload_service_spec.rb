require 'rails_helper'

RSpec.describe UploadService do
  describe '#call' do
    let(:file_path) { 'spec/fixtures/files/tasks.xlsx' }
    let(:upload_id) { 1 }

    it 'processes the Excel file and updates the upload status' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
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

    it 'logs error when starting upload update fails (rescue início)' do
      create(:upload, id: upload_id, status: :processing)
      fake_upload = instance_double(Upload)
      allow(fake_upload).to receive(:update).and_return(true)
      allow(fake_upload).to receive(:update)
        .with(hash_including(status: :processing, success_count: 0, error_count: 0, total_lines: 0))
        .and_raise(StandardError, 'start failed')
      allow(Upload).to receive(:find).with(upload_id).and_return(fake_upload)
      allow(Rails.logger).to receive(:error)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_empty)

      service = described_class.new(file_path, upload_id)
      expect { service.call }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with("Falha ao iniciar upload ##{upload_id}: start failed")
    end

    it 'handles row processing error and records increment_error (rescue por linha)' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      Task.create(company:, software:, code: '2267', name: 'T', date_opened: '01/09/2023', status: 'opened')

      allow(Rails.logger).to receive(:error)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)
      allow(service).to receive(:task_item_create).and_raise(StandardError, 'row failed')

      service.call
      upload.reload
      expect(upload.error_count).to be >= 1
      # error_messages guarda acumulado; split por quebra real
      expect(upload.error_messages.split("\n")).to include('row failed')
      expect(Rails.logger).to have_received(:error).with(/Erro ao processar linha \(code=2267\): row failed/)
    end

    it 'append_error_message com existente presente acumula e unifica' do
      service = described_class.new('f.xlsx', 1)
      result = service.send(:append_error_message, "e1\ne2", 'e2')
      expect(result.split("\n")).to match_array(%w[e1 e2])
    end

    it 'append_error_message com existente ausente inicia lista' do
      service = described_class.new('f.xlsx', 1)
      result = service.send(:append_error_message, nil, 'e1')
      expect(result).to eq('e1')
    end

    it 'não incrementa sucesso quando processed_ok é falso' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)
      allow(service).to receive_messages(task_item_create: false, create_task_and_task_item: false)

      service.call
      upload.reload
      expect(upload.success_count.to_i).to eq(0)
      expect(upload.total_lines.to_i).to eq(3)
    end

    it 'continues processing when company does not exist (status completed)' do
      upload = create(:upload, id: upload_id, status: :processing)
      Company.where(name: 'NobeSistemas').destroy_all
      company = create(:company, name: 'Example Company', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('completed')
    end

    it 'continues processing when software does not exist (status completed)' do
      upload = create(:upload, id: upload_id, status: :processing)
      create(:company, name: 'NobeSistemas', value: 10)
      Software.where(name: 'Almoxarifado').destroy_all

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('completed')
    end

    it 'skips rows where row[10] is blank' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_with_blank_row)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload
      expect(upload.status).to eq('completed')
      expect(upload.total_lines).to eq(2) # Only 2 valid rows, 1 blank row skipped
    end

    describe '#task_item_create' do
      it 'does not create a task item if already present' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
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

        company = Company.create(name: 'NobeSistemas', value: 10)
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

      it 'handles StandardError exception in task_item_create and logs error' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: '123', name: 'Task example', date_opened: '01/09/2023', status: 'opened')

        service.instance_variable_set(:@company_id, company.id)
        service.instance_variable_set(:@software_id, software.id)
        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, '2023-01-01')
        service.instance_variable_set(:@hour_start, '12:00')
        service.instance_variable_set(:@status, 'pending')

        allow(TaskItem).to receive(:where).and_raise(StandardError, 'Database connection error')

        allow(Rails.logger).to receive(:error)

        expect { service.send(:task_item_create) }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Erro ao verificar TaskItem existente: Database connection error')
      end
    end

    private

    def mock_excel
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      row_one = []
      row_one[0] = cell_struct.new('Sexta')
      row_one[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_one[2] = cell_struct.new('07:12', '07:12')
      row_one[3] = cell_struct.new('08:28', '08:28')
      row_one[7] = cell_struct.new('Almoxarifado')
      row_one[8] = cell_struct.new('Finalizado')
      row_one[10] = cell_struct.new('2267: Mensagens de erro ou sucesso, não estã estilizadas')

      row_two = []
      row_two[0] = cell_struct.new('Sexta')
      row_two[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_two[2] = cell_struct.new('08:29', '08:29')
      row_two[3] = cell_struct.new('10:22', '10:22')
      row_two[7] = cell_struct.new('Almoxarifado')
      row_two[8] = cell_struct.new('Finalizado')
      row_two[10] = cell_struct.new('2180: Tela Solicitante - Erro no cadastro')

      row_three = []
      row_three[0] = cell_struct.new('Sexta')
      row_three[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_three[2] = cell_struct.new('10:23', '10:23')
      row_three[3] = cell_struct.new('12:38', '12:38')
      row_three[7] = cell_struct.new('Almoxarifado')
      row_three[8] = cell_struct.new('Finalizado')
      row_three[10] = cell_struct.new('2254: Exclusão de Transferências - Erro no cadastro')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row_one)
        .and_yield(row_two)
        .and_yield(row_three)

      mock_excel_instance
    end

    def mock_excel_dublicate_task
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      row_one = []
      row_one[0] = cell_struct.new('Sexta')
      row_one[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_one[2] = cell_struct.new('08:29', '08:29')
      row_one[3] = cell_struct.new('10:22', '10:22')
      row_one[7] = cell_struct.new('Almoxarifado')
      row_one[8] = cell_struct.new('Finalizado')
      row_one[10] = cell_struct.new('2180: Tela Solicitante - Erro no cadastro')

      row_two = []
      row_two[0] = cell_struct.new('Sexta')
      row_two[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_two[2] = cell_struct.new('08:29', '08:29')
      row_two[3] = cell_struct.new('10:22', '10:22')
      row_two[7] = cell_struct.new('Almoxarifado')
      row_two[8] = cell_struct.new('Finalizado')
      row_two[10] = cell_struct.new('2180: Tela Solicitante - Erro no cadastro')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row_one)
        .and_yield(row_two)

      mock_excel_instance
    end

    def mock_excel_with_blank_row
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      # Row with valid data
      row_one = []
      row_one[0] = cell_struct.new('Sexta')
      row_one[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_one[2] = cell_struct.new('07:12', '07:12')
      row_one[3] = cell_struct.new('08:28', '08:28')
      row_one[7] = cell_struct.new('Almoxarifado')
      row_one[8] = cell_struct.new('Finalizado')
      row_one[10] = cell_struct.new('2267: Mensagens de erro ou sucesso, não estã estilizadas')

      # Row with blank row[10] - this should be skipped
      row_blank = []
      row_blank[0] = cell_struct.new('Sexta')
      row_blank[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_blank[2] = cell_struct.new('08:29', '08:29')
      row_blank[3] = cell_struct.new('10:22', '10:22')
      row_blank[7] = cell_struct.new('Almoxarifado')
      row_blank[8] = cell_struct.new('Finalizado')
      row_blank[10] = cell_struct.new('') # Blank value

      # Another row with valid data
      row_three = []
      row_three[0] = cell_struct.new('Sexta')
      row_three[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row_three[2] = cell_struct.new('10:23', '10:23')
      row_three[3] = cell_struct.new('12:38', '12:38')
      row_three[7] = cell_struct.new('Almoxarifado')
      row_three[8] = cell_struct.new('Finalizado')
      row_three[10] = cell_struct.new('2254: Exclusão de Transferências - Erro no cadastro')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row_one)
        .and_yield(row_blank)
        .and_yield(row_three)

      mock_excel_instance
    end
  end
end

def mock_excel_empty
  instance_double(Roo::Excelx).tap do |mock|
    allow(mock).to receive(:each_row_streaming).with(offset: 1)
  end
end