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
      expect(upload.total_lines.to_i).to eq(0)
    end

    it 'não incrementa nada quando excel está vazio (linha 90 sem processamento)' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_empty)

      service = described_class.new(file_path, upload_id)
      service.call
      upload.reload
      expect(upload.success_count.to_i).to eq(0)
      expect(upload.error_count.to_i).to eq(0)
      expect(upload.total_lines.to_i).to eq(0)
      expect(upload.status).to eq('completed')
    end

    it 'quando preferred é hora HH:MM usa find_code_name como fallback' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      mock = instance_double(Roo::Excelx)
      cell = Struct.new(:value, :formatted_value)
      row = []
      row[10] = cell.new('08:29', '08:29')
      row[1] = cell.new('01/09/2023', '01/09/2023')
      row[2] = cell.new('08:29', '08:29')
      row[3] = cell.new('10:22', '10:22')
      row[7] = cell.new('Almoxarifado', 'Almoxarifado')
      row[8] = cell.new('Finalizado', 'Finalizado')
      row[9] = cell.new('2180: Fallback via find_code_name')
      allow(mock).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock)

      service = described_class.new(file_path, upload_id)
      service.call
      t = Task.find_by(code: '2180')
      expect(t).not_to be_nil
      expect(t.name).to eq('Fallback via find_code_name')
    end

    it 'quando preferred tem hífen usa preferred e extrai code/name' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('1234 - Hífen Case')

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.where(company_id: company.id, code: '1234').first
      expect(t).not_to be_nil
      expect(t.name).to eq('Hífen Case')
    end

    it 'quando preferred usa em dash extrai code/name' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new("8123 — Em dash case")

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.where(company_id: company.id, code: '8123').first
      expect(t).not_to be_nil
      expect(t.name).to eq('Em dash case')
    end

    it 'quando preferred não contém code usa find_code_name' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[5] = cell_struct.new('4321: Via find_code_name')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('Texto sem separador')

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.where(company_id: company.id, code: '4321').first
      expect(t).not_to be_nil
      expect(t.name).to eq('Via find_code_name')
    end

    it 'quando preferred vazio usa find_code_name' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[5] = cell_struct.new('7001: Do início da linha')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('', nil)

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.where(company_id: company.id, code: '7001').first
      expect(t).not_to be_nil
      expect(t.name).to eq('Do início da linha')
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

    it 'ensure_company cria NobeSistemas com valor do primeiro company' do
      Company.where('name ilike ?', 'nobesistemas').destroy_all
      base = Company.create(name: 'Example Company', value: 77)
      service = described_class.new(file_path, upload_id)
      service.send(:ensure_company)
      c = Company.where('name ilike ?', 'nobesistemas').first
      expect(c).not_to be_nil
      expect(c.value).to eq(base.value)
    end

    it 'ensure_company não cria duplicado quando já existe' do
      Company.where('name ilike ?', 'nobesistemas').destroy_all
      Company.create(name: 'NobeSistemas', value: 10)
      service = described_class.new(file_path, upload_id)
      expect { service.send(:ensure_company) }
        .not_to change { Company.where('name ilike ?', 'nobesistemas').count }
    end

    it 'atribui @company_id para NobeSistemas durante call' do
      upload = create(:upload, id: upload_id, status: :processing)
      Company.where('name ilike ?', 'nobesistemas').destroy_all

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel)

      service = described_class.new(file_path, upload_id)
      service.call

      task = Task.find_by(code: '2180')
      expect(task.company.name).to eq('NobeSistemas')
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

    it 'preenche horas via find_hours quando horas em branco' do
      create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_hours_in_text)

      service = described_class.new(file_path, upload_id)
      service.call

      task = Task.find_by(code: '2180')
      item = task.task_items.last
      expect(item.as_json[:hourStart]).to eq('08:29')
      expect(item.as_json[:hourEnd]).to eq('10:22')
    end

    it 'mantém hour_start presente e preenche apenas hour_end via find_hours' do
      create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end

      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:00', '08:00')
      row[3] = cell_struct.new('', nil)
      row[5] = cell_struct.new('Fim 09:00')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('5000: Preserva início')

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.find_by(code: '5000')
      item = t.task_items.first
      expect(item.as_json[:hourStart]).to eq('08:00')
      expect(item.as_json[:hourEnd]).to eq('09:00')
    end

    it 'usa fallback de data/status/software quando colunas principais estão vazias' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('', nil)
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[4] = cell_struct.new('01/09/2023', '01/09/2023')
      row[6] = cell_struct.new('Almoxarifado')
      row[7] = cell_struct.new('', nil)
      row[8] = cell_struct.new('', nil)
      row[9] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('2181: Fallbacks no call')

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_instance)

      service = described_class.new(file_path, upload_id)
      service.call

      t = Task.where(company_id: company.id, software_id: software.id, code: '2181').first
      expect(t).not_to be_nil
      expect(t.date_opened).to eq(Date.strptime('01/09/2023', '%d/%m/%Y'))
      item = t.task_items.first
      expect(item).not_to be_nil
      expect(item.as_json[:hourStart]).to eq('08:29')
      expect(item.as_json[:hourEnd]).to eq('10:22')
      expect(item.status).to eq('finalized')
    end

    it 'mapeia status para status_task correto em create_task_and_task_item' do
      create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')

      service = described_class.new(file_path, upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@name, 'X')
      service.instance_variable_set(:@date_opened, Date.current)

      mappings = {
        'finalized' => 'finalized',
        'pending' => 'opened',
        'reopened' => 'reopened',
        'delivered' => 'delivered',
        'invalid' => 'opened',
      }

      mappings.each_with_index do |(input, expected), idx|
        code = "M#{idx}"
        service.instance_variable_set(:@code, code)
        service.instance_variable_set(:@status, input)
        result = service.send(:create_task_and_task_item)
        expect(result).to be(true).or be(false)
        t = Task.find_by(code:)
        expect(t).not_to be_nil
        expect(t.status).to eq(expected)
      end
    end

    it 'retorna false quando task não persiste em create_task_and_task_item' do
      create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')

      service = described_class.new(file_path, upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'NP1')
      service.instance_variable_set(:@name, 'X')
      service.instance_variable_set(:@date_opened, Date.current)
      service.instance_variable_set(:@status, 'finalized')

      allow(Task).to receive(:create).and_return(Task.new)
      expect(service.send(:create_task_and_task_item)).to be(false)
    end

    it 'incrementa erro quando task_item_create retorna false' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')

      service = described_class.new(file_path, upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'E1')
      service.instance_variable_set(:@name, 'X')
      service.instance_variable_set(:@date_opened, Date.current)
      service.instance_variable_set(:@status, 'finalized')

      allow(service).to receive(:task_item_create).and_return(false)
      expect(service.send(:create_task_and_task_item)).to be(false)
      upload.reload
      expect(upload.error_count.to_i).to be >= 1
    end

    it 'fallback para code_name sem dígitos iniciais (ramo else)' do
      upload = create(:upload, id: upload_id, status: :processing)
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_non_digit_code)

      service = described_class.new(file_path, upload_id)

      service.call
      upload.reload

      expect(upload.status).to eq('completed')
      task = Task.where(company:, software: Software.find_by(name: 'Almoxarifado'), code: 'ABC').first
      expect(task).not_to be_nil
      expect(task.name).to eq('Sem digitos')
    end

    it 'ignora linha quando empresa/software/code ausente em create_task_and_task_item' do
      upload = create(:upload, id: upload_id, status: :processing)
      Company.where(name: 'NobeSistemas').destroy_all
      # Não cria software para forçar software_id nil

      allow(Roo::Excelx).to receive(:new).with(file_path).and_return(mock_excel_code_blank)

      service = described_class.new(file_path, upload_id)
      allow(Rails.logger).to receive(:error)

      service.call
      upload.reload

      expect(upload.error_count).to be >= 1
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

        result = service.send(:task_item_create)
        expect(result).to eq(true)
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

        allow(TaskItem).to receive(:exists?).and_raise(StandardError, 'Database connection error')

        allow(Rails.logger).to receive(:error)

        expect { service.send(:task_item_create) }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Erro ao verificar TaskItem existente: Database connection error')
      end

      it 'cria item mesmo após erro em exists? e retorna true' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: 'X01', name: 'T', date_opened: Date.today, status: 'opened')

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, Date.today)
        service.instance_variable_set(:@hour_start, '08:00')
        service.instance_variable_set(:@date_end, Date.today)
        service.instance_variable_set(:@hour_end, '09:00')
        service.instance_variable_set(:@status, 'pending')

        allow(TaskItem).to receive(:exists?).and_raise(StandardError, 'temporary error')
        expect { service.send(:task_item_create) }.to change { TaskItem.count }.by(1)
        expect(service.send(:task_item_create)).to eq(true)
      end

      it 'retorna false quando @task não está persistida' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        task = Task.new # não persistido
        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@status, 'pending')
        service.instance_variable_set(:@hour_start, '12:00')

        expect(service.send(:task_item_create)).to be(false)
      end

      it 'retorna false quando @task é nil' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)
        service.instance_variable_set(:@status, 'pending')
        service.instance_variable_set(:@hour_start, '12:00')
        expect(service.send(:task_item_create)).to be(false)
      end

      it 'cria item quando task persistida e retorna true' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: 'C01', name: 'T1', date_opened: Date.today, status: 'opened')

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, Date.today)
        service.instance_variable_set(:@hour_start, '12:00')
        service.instance_variable_set(:@date_end, Date.today)
        service.instance_variable_set(:@hour_end, '13:00')
        service.instance_variable_set(:@status, 'pending')

        expect { service.send(:task_item_create) }.to change { TaskItem.count }.by(1)
        expect(service.send(:task_item_create)).to eq(true)
      end

      it 'retorna false quando criação falha (created.persisted? == false)' do
        service = described_class.new('example.xlsx', upload_id)
        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: 'Z01', name: 'T', date_opened: Date.today, status: 'opened')

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@date_start, Date.today)
        service.instance_variable_set(:@hour_start, '08:00')
        service.instance_variable_set(:@date_end, Date.today)
        service.instance_variable_set(:@hour_end, '09:00')
        service.instance_variable_set(:@status, 'pending')

        allow(TaskItem).to receive(:exists?).and_return(false)
        fake_assoc = double('Assoc')
        allow(task).to receive(:task_items).and_return(fake_assoc)
        allow(fake_assoc).to receive(:create).and_return(double('TI', persisted?: false))

        expect(service.send(:task_item_create)).to be(false)
      end

      it 'retorna false quando @status vazio' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: '123', name: 'Task example', date_opened: '01/09/2023', status: 'opened')

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@status, '')
        service.instance_variable_set(:@hour_start, '12:00')

        expect(service.send(:task_item_create)).to be(false)
      end

      it 'retorna false quando @hour_start vazio' do
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)

        company = Company.create(name: 'NobeSistemas', value: 10)
        software = Software.create(company:, name: 'Almoxarifado')
        task = Task.create(company:, software:, code: '123', name: 'Task example', date_opened: '01/09/2023', status: 'opened')

        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@status, 'pending')
        service.instance_variable_set(:@hour_start, '')

        expect(service.send(:task_item_create)).to be(false)
      end

      it 'retorna false' do
        task = Task.new # não salva, então não está persistida
        upload_id = 1
        file_path = 'example.xlsx'
        service = described_class.new(file_path, upload_id)
        service.instance_variable_set(:@task, task)
        service.instance_variable_set(:@status, 'pending')
        service.instance_variable_set(:@hour_start, '12:00')

        expect(service.send(:task_item_create)).to eq(false)
      end

      it 'company_id fica nil quando NobeSistemas não é encontrado' do
        upload = create(:upload, id: upload_id, status: :processing)
        Company.where('name ilike ?', 'nobesistemas').destroy_all
        service = described_class.new(file_path, upload_id)
        allow(service).to receive(:ensure_company) # não cria empresa padrão
        allow(Company).to receive(:where).with('name ilike ?', 'nobesistemas').and_return(Company.none)

        service.call
        expect(service.instance_variable_get(:@company_id)).to be_nil
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

    def mock_excel_hours_in_text
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('', nil)
      row[3] = cell_struct.new('', nil)
      row[4] = cell_struct.new('Inicio 08h 29')
      row[5] = cell_struct.new('Fim 10h 22')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('2180: Qualquer')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row)

      mock_excel_instance
    end

    def mock_excel_code_blank
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:00', '08:00')
      row[3] = cell_struct.new('09:00', '09:00')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new(' : Sem código')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row)

      mock_excel_instance
    end

    def mock_excel_non_digit_code
      mock_excel_instance = instance_double(Roo::Excelx)

      cell_struct =
        Struct.new(:value, :formatted_value) do
          def blank?
            value.nil? || value.to_s.strip == ''
          end
        end

      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:00', '08:00')
      row[3] = cell_struct.new('09:00', '09:00')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('ABC: Sem digitos')

      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1)
        .and_yield(row)

      mock_excel_instance
    end
  end

  describe 'private helpers' do
    it 'status_parse maps variants and unknown returns nil' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:status_parse, 'Finalizado')).to eq('finalized')
      expect(service.send(:status_parse, 'finalizada')).to eq('finalized')
      expect(service.send(:status_parse, 'Concluido')).to eq('finalized')
      expect(service.send(:status_parse, 'Pendência')).to eq('pending')
      expect(service.send(:status_parse, 'xpto')).to be_nil
      expect(service.send(:status_parse, nil)).to be_nil
    end

    it 'safe_cell prefers formatted_value and handles nils' do
      service = described_class.new('f.xlsx', 1)
      cell_struct = Struct.new(:value, :formatted_value)
      row = []
      row[0] = cell_struct.new('raw', 'formatted')
      row[1] = cell_struct.new('raw', nil)
      row[2] = nil

      expect(service.send(:safe_cell, row, 0)).to eq('formatted')
      expect(service.send(:safe_cell, row, 1)).to eq('raw')
      expect(service.send(:safe_cell, row, 2)).to eq('')
    end

    it 'parse_date supports dd/mm/YYYY, Date and Time' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:parse_date, '29/11/2025')).to eq(Date.strptime('29/11/2025', '%d/%m/%Y'))
      d = Date.new(2025, 11, 29)
      expect(service.send(:parse_date, d)).to eq(d)
      t = Time.zone.local(2025, 11, 29, 9, 45, 0)
      expect(service.send(:parse_date, t)).to eq(Date.new(2025, 11, 29))
      expect(service.send(:parse_date, '2025-11-29')).to eq(Date.new(2025, 11, 29))
      expect(service.send(:parse_date, 'invalid')).to be_nil
    end

    it 'parse_date fallback via Date.parse para formatos livres' do
      service = described_class.new('f.xlsx', 1)
      # Date.parse aceita uma variedade de formatos; aqui garantimos o fallback
      expect(service.send(:parse_date, 'Nov 29, 2025')).to eq(Date.new(2025, 11, 29))
    end

    it 'parse_date suporta DateTime' do
      service = described_class.new('f.xlsx', 1)
      dt = DateTime.new(2025, 11, 29, 12, 0, 0)
      expect(service.send(:parse_date, dt)).to eq(dt.to_date)
    end

    it 'normalize_hour parses multiple formats and returns HH:MM' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:normalize_hour, '08:29')).to eq('08:29')
      expect(service.send(:normalize_hour, '8h 29')).to eq('08:29')
      expect(service.send(:normalize_hour, '8 29')).to eq('08:29')
      expect(service.send(:normalize_hour, '8-29')).to eq('08:29')
      expect(service.send(:normalize_hour, '19:43:37')).to eq('19:43')
      expect(service.send(:normalize_hour, '')).to eq('')
    end

    it 'scan_hour extracts HH:MM inside larger strings' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:scan_hour, 'Inicio 08h 29 Fim 10h 22')).to eq('08:29')
      expect(service.send(:scan_hour, 'Começo 19:43:37')).to eq('19:43')
      expect(service.send(:scan_hour, 'xx 7 02 yy')).to eq('07:02')
      expect(service.send(:scan_hour, 'Sem hora')).to eq('')
    end

    it 'find_software_id returns nil for blank and id for exact match' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      Software.create(company:, name: 'Tributario')
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:find_software_id, '  ')).to be_nil
      expect(service.send(:find_software_id, 'tributario')).not_to be_nil
    end

    it 'safe_cell entra no rescue e usa value' do
      service = described_class.new('f.xlsx', 1)
      obj = Class.new do
        def formatted_value
          raise 'boom'
        end

        def value
          'ok'
        end
      end.new
      row = [obj]
      expect(service.send(:safe_cell, row, 0)).to eq('ok')
    end

    it 'safe_cell sem value retorna to_s' do
      service = described_class.new('f.xlsx', 1)
      obj = Class.new do
        def to_s
          'str'
        end
      end.new
      row = [obj]
      expect(service.send(:safe_cell, row, 0)).to eq('str')
    end

    it 'safe_cell usa value quando formatted_value é nil' do
      service = described_class.new('f.xlsx', 1)
      obj = Class.new do
        def formatted_value
          nil
        end

        def value
          'raw'
        end
      end.new
      row = [obj]
      expect(service.send(:safe_cell, row, 0)).to eq('raw')
    end

    it 'find_update memoiza resultado (||= chama Upload.find apenas uma vez)' do
      upload = create(:upload, id: 777, status: :processing)
      service = described_class.new('f.xlsx', 777)
      calls = 0
      allow(Upload).to receive(:find).with(777) do |*_args|
        calls += 1
        upload
      end
      # primeira chamada carrega
      expect(service.send(:find_update)).to eq(upload)
      # segunda chamada reutiliza memoização
      expect(service.send(:find_update)).to eq(upload)
      expect(calls).to eq(1)
    end

    it 'find_date_cell retorna célula com data válida' do
      service = described_class.new('f.xlsx', 1)
      row = ['x', '01/11/2025', 'y']
      expect(service.send(:find_date_cell, row)).to eq('01/11/2025')
    end

    it 'find_date_cell retorna vazio quando nenhum valor é data' do
      service = described_class.new('f.xlsx', 1)
      row = ['foo', 'bar', 'baz']
      expect(service.send(:find_date_cell, row)).to eq('')
    end

    it 'find_status_cell retorna célula que contém status reconhecível' do
      service = described_class.new('f.xlsx', 1)
      row = ['x', 'Pendência', 'y']
      expect(service.send(:find_status_cell, row)).to eq('Pendência')
    end

    it 'find_status_cell retorna vazio quando nenhum status encontrado' do
      service = described_class.new('f.xlsx', 1)
      row = ['x', 'y']
      expect(service.send(:find_status_cell, row)).to eq('')
    end

    it 'find_code_name encontra último padrão com código: nome' do
      service = described_class.new('f.xlsx', 1)
      row = ['foo', 'bar', '1234: Nome', '456- Outra']
      expect(service.send(:find_code_name, row)).to eq('456- Outra')
    end

    it 'find_code_name ignora horas e pega code:name adequado' do
      service = described_class.new('f.xlsx', 1)
      row = ['08:00', 'x', '9999: Teste']
      expect(service.send(:find_code_name, row)).to eq('9999: Teste')
    end

    it 'find_software_cell retorna nome normalizado presente na linha' do
      create(:software, name: 'Almoxarifado', company: create(:company, value: 10))
      service = described_class.new('f.xlsx', 1)
      row = ['x', 'almoxarifado']
      expect(service.send(:find_software_cell, row)).to eq('almoxarifado')
    end

    it 'find_software_cell retorna vazio quando não encontra' do
      service = described_class.new('f.xlsx', 1)
      row = ['x', 'y']
      expect(service.send(:find_software_cell, row)).to eq('')
    end

    it 'find_hours retorna início e fim válidos' do
      service = described_class.new('f.xlsx', 1)
      row = ['a 08:00', 'b', 'c 10:00']
      expect(service.send(:find_hours, row)).to eq(['08:00', '10:00'])
    end

    it 'find_hours retorna apenas início quando fim inválido' do
      service = described_class.new('f.xlsx', 1)
      row = ['a 10:00', 'b 09:59']
      expect(service.send(:find_hours, row)).to eq(['10:00', nil])
    end

    it 'find_hours retorna apenas início quando não encontra fim' do
      service = described_class.new('f.xlsx', 1)
      row = ['a 08:00', 'b']
      expect(service.send(:find_hours, row)).to eq(['08:00', nil])
    end

    it 'find_hours entra no rescue quando Time.zone.parse levanta erro e retorna [s, nil]' do
      service = described_class.new('f.xlsx', 1)
      row = ['a 08:00', 'b 09:00']
      # stub de Time.zone.parse para causar erro
      allow(Time.zone).to receive(:parse).and_raise(StandardError)
      expect(service.send(:find_hours, row)).to eq(['08:00', nil])
    end

    it 'ensure_software com nome vazio não faz nada' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:ensure_software, '   ')).to be_nil
    end

    it 'ensure_software sem empresa não cria software' do
      Company.where(name: 'NobeSistemas').destroy_all
      service = described_class.new('f.xlsx', 1)
      service.send(:ensure_software, 'Almoxarifado')
      expect(Software.where(name: 'Almoxarifado').count).to eq(0)
    end

    it 'ensure_software cria novo quando não existe e seta @software_id' do
      Company.where(name: 'NobeSistemas').destroy_all
      company = create(:company, name: 'NobeSistemas', value: 10)
      expect(Software.where(company_id: company.id).count).to eq(0)

      service = described_class.new('f.xlsx', 1)
      service.send(:ensure_software, 'Almoxarifado')

      created = Software.where(company_id: company.id).first
      expect(created).not_to be_nil
      expect(created.name).to eq('Almoxarifado')
      expect(service.instance_variable_get(:@software_id)).to eq(created.id)
    end

    it 'ensure_software usa existente quando já cadastrado e não duplica' do
      Company.where(name: 'NobeSistemas').destroy_all
      company = create(:company, name: 'NobeSistemas', value: 10)
      existing = create(:software, company:, name: 'Almoxarifado')

      service = described_class.new('f.xlsx', 1)
      expect { service.send(:ensure_software, 'Almoxarifado') }
        .not_to change { Software.where(company_id: company.id).count }
      expect(service.instance_variable_get(:@software_id)).to eq(existing.id)
    end

    it 'ensure_company usa valor padrão quando não há empresas' do
      Company.delete_all
      service = described_class.new('f.xlsx', 1)
      service.send(:ensure_company)
      c = Company.where('name ilike ?', 'nobesistemas').first
      expect(c).not_to be_nil
      expect(c.value).to eq(10)
    end

    it 'status_parse inclui entregue e reaberto' do
      service = described_class.new('f.xlsx', 1)
      expect(service.send(:status_parse, 'entregue')).to eq('delivered')
      expect(service.send(:status_parse, 'reaberto')).to eq('reopened')
      expect(service.send(:status_parse, 'reaberta')).to eq('reopened')
      expect(service.send(:status_parse, 'Final')).to eq('finalized')
    end

    it 'safe_cell retorna vazio para célula nil' do
      service = described_class.new('f.xlsx', 1)
      row = [nil]
      expect(service.send(:safe_cell, row, 0)).to eq('')
    end

    it 'normalize_hour remove NBSP e formata corretamente' do
      service = described_class.new('f.xlsx', 1)
      nbsp = "08\u00A029"
      expect(service.send(:normalize_hour, nbsp)).to eq('08:29')
    end

    it 'find_code_name retorna vazio quando não encontra padrão' do
      service = described_class.new('f.xlsx', 1)
      row = ['foo', 'bar']
      expect(service.send(:find_code_name, row)).to eq('')
    end

    it 'call captura erro externo e marca failed no upload' do
      upload = create(:upload, id: 999, status: :processing)
      fp = 'spec/fixtures/files/tasks.xlsx'
      allow(Roo::Excelx).to receive(:new).with(fp).and_raise(StandardError, 'explode')
      service = described_class.new(fp, 999)
      service.call
      upload.reload
      expect(upload.status).to eq('failed')
      expect(upload.error_messages).to eq('explode')
    end

    it 'create_task_and_task_item retorna false quando dados inválidos' do
      service = described_class.new('f.xlsx', 1)
      service.instance_variable_set(:@company_id, nil)
      service.instance_variable_set(:@software_id, nil)
      service.instance_variable_set(:@code, '')
      allow(service).to receive(:increment_error)
      expect(service.send(:create_task_and_task_item)).to be(false)
    end
  end

  describe 'branches extras' do
    let(:upload_id) { create(:upload, status: :processing).id }

    it 'quando preferred tem dois pontos usa preferred e extrai code/name' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      create(:software, company:, name: 'Almoxarifado')

      cell_struct = Struct.new(:value, :formatted_value) do
        def blank?
          value.nil? || value.to_s.strip == ''
        end
      end
      row = []
      row[0] = cell_struct.new('Sexta')
      row[1] = cell_struct.new('01/09/2023', '01/09/2023')
      row[2] = cell_struct.new('08:29', '08:29')
      row[3] = cell_struct.new('10:22', '10:22')
      row[5] = cell_struct.new('9999: Outro')
      row[7] = cell_struct.new('Almoxarifado')
      row[8] = cell_struct.new('Finalizado')
      row[10] = cell_struct.new('4322: Via preferred colon')

      mock_excel_instance = instance_double(Roo::Excelx)
      allow(mock_excel_instance).to receive(:each_row_streaming).with(offset: 1).and_yield(row)
      allow(Roo::Excelx).to receive(:new).and_return(mock_excel_instance)

      described_class.new('file.xlsx', upload_id).call

      t = Task.find_by(code: '4322')
      expect(t).not_to be_nil
      expect(t.name).to eq('Via preferred colon')
    end

    it 'status_parse cobre todas as variações conhecidas' do
      service = described_class.new('x.xlsx', upload_id)
      expect(service.send(:status_parse, 'Finalizado')).to eq('finalized')
      expect(service.send(:status_parse, 'Finalizada')).to eq('finalized')
      expect(service.send(:status_parse, 'Final')).to eq('finalized')
      expect(service.send(:status_parse, 'Concluido')).to eq('finalized')
      expect(service.send(:status_parse, 'Concluída')).to eq('finalized')
      expect(service.send(:status_parse, 'Pendência')).to eq('pending')
      expect(service.send(:status_parse, 'pending')).to eq('pending')
      expect(service.send(:status_parse, 'Entregue')).to eq('delivered')
      expect(service.send(:status_parse, 'Reaberto')).to eq('reopened')
      expect(service.send(:status_parse, 'Reaberta')).to eq('reopened')
      expect(service.send(:status_parse, 'xpto')).to be_nil
    end

    it 'parse_date suporta YYYY-MM-DD' do
      service = described_class.new('x.xlsx', upload_id)
      expect(service.send(:parse_date, '2025-11-29')).to eq(Date.new(2025, 11, 29))
    end

    it 'normalize_hour retorna vazio quando não há match' do
      service = described_class.new('x.xlsx', upload_id)
      expect(service.send(:normalize_hour, 'sem hora')).to eq('')
    end

    it 'scan_hour retorna vazio quando não há match' do
      service = described_class.new('x.xlsx', upload_id)
      expect(service.send(:scan_hour, 'texto qualquer')).to eq('')
    end

    it 'create_task_and_task_item mapeia status finalized' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      service = described_class.new('x.xlsx', upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'M01')
      service.instance_variable_set(:@name, 'Map finalize')
      service.instance_variable_set(:@date_opened, Date.today)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'finalized')
      expect(service.send(:create_task_and_task_item)).to eq(true)
      expect(Task.find_by(code: 'M01').status).to eq('finalized')
    end

    it 'create_task_and_task_item mapeia status pending para opened (após item fica reopened)' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      service = described_class.new('x.xlsx', upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'M02')
      service.instance_variable_set(:@name, 'Map pending')
      service.instance_variable_set(:@date_opened, Date.today)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'pending')
      expect(service.send(:create_task_and_task_item)).to eq(true)
      expect(Task.find_by(code: 'M02').status).to eq('reopened')
    end

    it 'create_task_and_task_item mapeia status reopened' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      service = described_class.new('x.xlsx', upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'M03')
      service.instance_variable_set(:@name, 'Map reopened')
      service.instance_variable_set(:@date_opened, Date.today)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'reopened')
      allow(service).to receive(:task_item_create).and_return(true)
      expect(service.send(:create_task_and_task_item)).to eq(true)
      expect(Task.find_by(code: 'M03').status).to eq('reopened')
    end

    it 'create_task_and_task_item mapeia status delivered' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      service = described_class.new('x.xlsx', upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'M04')
      service.instance_variable_set(:@name, 'Map delivered')
      service.instance_variable_set(:@date_opened, Date.today)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'delivered')
      allow(service).to receive(:task_item_create).and_return(true)
      expect(service.send(:create_task_and_task_item)).to eq(true)
      expect(Task.find_by(code: 'M04').status).to eq('delivered')
    end

    it 'create_task_and_task_item mapeia status desconhecido para opened' do
      company = create(:company, name: 'NobeSistemas', value: 10)
      software = create(:software, company:, name: 'Almoxarifado')
      service = described_class.new('x.xlsx', upload_id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'M05')
      service.instance_variable_set(:@name, 'Map unknown')
      service.instance_variable_set(:@date_opened, Date.today)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'other')
      allow(service).to receive(:task_item_create).and_return(true)
      expect(service.send(:create_task_and_task_item)).to eq(true)
      expect(Task.find_by(code: 'M05').status).to eq('opened')
    end

    it 'parse_date fallback via Date.parse para formatos livres' do
      service = described_class.new('x.xlsx', upload_id)
      expect(service.send(:parse_date, '29 Nov 2025')).to eq(Date.new(2025, 11, 29))
    end
  end
end

def mock_excel_empty
  instance_double(Roo::Excelx).tap do |mock|
    allow(mock).to receive(:each_row_streaming).with(offset: 1)
  end
end
