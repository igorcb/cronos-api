require 'rails_helper'

RSpec.describe UploadJsonService, type: :service do
  describe '#call' do
    let(:company) { create(:company, name: 'NobeSistemas', value: 10) }
    let!(:software) { create(:software, company:, name: 'Almoxarifado') }
    let(:upload) { create(:upload, file_name: 'payload.json', status: :processing, total_lines: 0, success_count: 0, error_count: 0, error_messages: '') }

    it 'processa linhas JSON criando task e task_items, atualiza contadores' do
      rows = [
        { codeName: '2180: Tela Solicitante - Erro no cadastro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '08:29', hourEnd: '10:22', status: 'Finalizado' },
        { codeName: '2267: Mensagens de erro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '10:23', hourEnd: '12:38', status: 'Finalizado' },
      ]

      described_class.new(rows, upload.id).call

      upload.reload
      expect(upload.status).to eq('completed')
      expect(upload.total_lines).to eq(2)
      expect(upload.success_count).to eq(2)
      expect(upload.error_count).to eq(0)

      tasks = Task.where(company:, software:)
      expect(tasks.count).to eq(2)
      expect(TaskItem.count).to eq(2)
    end

    it 'ignora linhas inválidas e acumula erros' do
      rows = [
        { codeName: '', software: 'Almoxarifado' },
        { codeName: '9999: X', software: '', date: '01/09/2023' },
      ]

      described_class.new(rows, upload.id).call

      upload.reload
      expect(upload.status).to eq('completed')
      expect(upload.total_lines).to eq(0) # nenhuma linha válida contada
      expect(upload.success_count).to eq(0)
      expect(upload.error_count).to be >= 1
    end

    it 'executa em modo sync via controller com rows JSON' do
      rows = [
        { codeName: '2180: Tela Solicitante - Erro no cadastro', software: 'Almoxarifado', date: '01/09/2023', hourStart: '08:29', hourEnd: '10:22', status: 'Finalizado' },
      ]
      upload = create(:upload, file_name: 'payload.json', status: :processing, total_lines: 0, success_count: 0, error_count: 0, error_messages: '')
      expect { described_class.new(rows, upload.id).call }.to change(TaskItem, :count).by(1)
    end
  end

  describe 'branches' do
    let(:company) { create(:company, name: 'NobeSistemas', value: 10) }
    let!(:software) { create(:software, company:, name: 'Almoxarifado') }
    let(:upload) { create(:upload, file_name: 'payload.json', status: :processing, total_lines: 0, success_count: 0, error_count: 0, error_messages: '') }

    it 'registra erro ao iniciar quando update falha' do
      service = described_class.new([], upload.id)
      allow(Rails.logger).to receive(:error)

      calls = 0
      upload_double = double('Upload')
      allow(upload_double).to receive(:update) do |*_args|
        calls += 1
        raise StandardError, 'init fail' if calls == 1
        true
      end
      allow(Upload).to receive(:find).with(upload.id).and_return(upload_double)

      expect { service.call }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/Falha ao iniciar upload #\d+: init fail/)
    end

    it 'task_item_create retorna false quando @task é nil' do
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@status, 'pending')
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      expect(service.send(:task_item_create)).to be(false)
    end

    it 'task_item_create retorna false quando @task não está persistida' do
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, Task.new)
      service.instance_variable_set(:@status, 'pending')
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      expect(service.send(:task_item_create)).to be(false)
    end

    it 'task_item_create retorna false quando @status vazio' do
      task = Task.create(company:, software:, code: 'TJS01', name: 'X', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@status, '')
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      expect(service.send(:task_item_create)).to be(false)
    end

    it 'task_item_create retorna false quando @hour_start ou @hour_end vazio' do
      task = Task.create(company:, software:, code: 'TJS02', name: 'Y', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@status, 'pending')
      service.instance_variable_set(:@hour_start, '')
      service.instance_variable_set(:@hour_end, '09:00')
      expect(service.send(:task_item_create)).to be(false)
    end

    it 'task_item_create retorna true quando item já existe e atualiza status' do
      task = Task.create(company:, software:, code: 'TJS03', name: 'Z', date_opened: Date.today, status: 'opened')
      TaskItem.create(task:, date_start: Date.today, hour_start: '08:00', hour_end: '09:00', status: 'pending')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'pending')
      expect(service.send(:task_item_create)).to eq(true)
      expect(task.reload.status).to eq('opened').or eq('reopened').or eq('finalized')
    end

    it 'task_item_create retorna false quando criação falha (persisted? == false)' do
      task = Task.create(company:, software:, code: 'TJS07', name: 'Q', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
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

    it 'task_item_create cria item e retorna true quando não existe' do
      task = Task.create(company:, software:, code: 'TJS05', name: 'K', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@date_end, Date.today)
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'pending')
      expect { service.send(:task_item_create) }.to change { TaskItem.count }.by(1)
      expect(service.send(:task_item_create)).to eq(true)
    end

    it 'task_item_create lida com StandardError em exists? e registra erro' do
      task = Task.create(company:, software:, code: 'TJS04', name: 'W', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@date_start, Date.today)
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '09:00')
      service.instance_variable_set(:@status, 'pending')
      allow(TaskItem).to receive(:exists?).and_raise(StandardError, 'db error')
      allow(Rails.logger).to receive(:error)
      expect { service.send(:task_item_create) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with('Erro ao verificar TaskItem existente: db error')
    end

    it 'create_task_and_task_item retorna false quando task não persiste' do
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@company_id, company.id)
      service.instance_variable_set(:@software_id, software.id)
      service.instance_variable_set(:@code, 'TPX')
      service.instance_variable_set(:@name, 'N')
      service.instance_variable_set(:@date_opened, Date.today)
      allow(Task).to receive(:create).and_return(Task.new)
      expect(service.send(:create_task_and_task_item)).to be(false)
    end

    it 'create_task_and_task_item retorna false quando dados inválidos' do
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@company_id, nil)
      service.instance_variable_set(:@software_id, nil)
      service.instance_variable_set(:@code, '')
      allow(service).to receive(:increment_error)
      expect(service.send(:create_task_and_task_item)).to be(false)
    end

    it 'status_parse retorna nil para desconhecido' do
      service = described_class.new([], upload.id)
      expect(service.send(:status_parse, 'xpto')).to be_nil
    end

    it 'status_parse mapeia variações e desconhecido retorna nil' do
      service = described_class.new([], upload.id)
      expect(service.send(:status_parse, 'Finalizado')).to eq('finalized')
      expect(service.send(:status_parse, 'Finalizada')).to eq('finalized')
      expect(service.send(:status_parse, 'Concluido')).to eq('finalized')
      expect(service.send(:status_parse, 'Final')).to eq('finalized')
      expect(service.send(:status_parse, 'Concluída')).to be_nil
      expect(service.send(:status_parse, 'Pendência')).to eq('pending')
      expect(service.send(:status_parse, 'pending')).to eq('pending')
      expect(service.send(:status_parse, 'xpto')).to be_nil
      expect(service.send(:status_parse, nil)).to be_nil
    end

    it 'parse_date suporta formatos e retorna nil inválido' do
      service = described_class.new([], upload.id)
      d = Date.new(2025, 11, 29)
      t = Time.new(2025, 11, 29, 10, 30, 0)
      expect(service.send(:parse_date, '29/11/2025')).to eq(Date.strptime('29/11/2025', '%d/%m/%Y'))
      expect(service.send(:parse_date, d)).to eq(d)
      expect(service.send(:parse_date, t)).to eq(Date.new(2025, 11, 29))
      expect(service.send(:parse_date, 'invalid')).to be_nil
    end

    it 'find_software_id retorna id para nome exato e nil para vazio' do
      service = described_class.new([], upload.id)
      expect(service.send(:find_software_id, 'Almoxarifado')).to eq(software.id)
      expect(service.send(:find_software_id, '   ')).to be_nil
    end

    it 'pick seleciona primeiro valor presente entre chaves' do
      service = described_class.new([], upload.id)
      hash = { 'a' => nil, b: 'x', 'c' => 'y' }
      expect(service.send(:pick, hash, %w[a b c])).to eq('x')
    end

    it 'pick retorna nil quando nenhuma chave está presente' do
      service = described_class.new([], upload.id)
      hash = { 'a' => nil, b: nil }
      expect(service.send(:pick, hash, %w[a b])).to be_nil
    end

    it 'pick prioriza chave string quando presente' do
      service = described_class.new([], upload.id)
      hash = { 'a' => 'x', a: 'y' }
      expect(service.send(:pick, hash, %w[a])).to eq('x')
    end

    it 'task_item_create retorna false quando @hour_end vazio' do
      task = Task.create(company:, software:, code: 'TJS06', name: 'J', date_opened: Date.today, status: 'opened')
      service = described_class.new([], upload.id)
      service.instance_variable_set(:@task, task)
      service.instance_variable_set(:@status, 'pending')
      service.instance_variable_set(:@hour_start, '08:00')
      service.instance_variable_set(:@hour_end, '')
      expect(service.send(:task_item_create)).to be(false)
    end

    it 'marca upload como failed quando ocorre erro fora do bloco interno' do
      rows = [{ any: 'data' }]
      service = described_class.new(rows, upload.id)
      allow_any_instance_of(UploadJsonService).to receive(:pick).and_raise(StandardError, 'boom')
      service.call
      upload.reload
      expect(upload.status).to eq('failed')
      expect(upload.error_messages).to eq('boom')
    end
  end
end
