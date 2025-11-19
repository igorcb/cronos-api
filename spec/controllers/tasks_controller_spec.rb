require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  describe 'GET /tasks' do
    let!(:company) { create(:company, value: 10) }
    let(:software) { create(:software, company:, name: 'Software Example') }

    let(:task_one) {
      {
        company:,
        software:,
        code: '1025',
        name: 'Anything',
        description: 'Laborum et culpa veniam laboris voluptate',
        date_opened: '2023-10-01',
        total_hours: '00:00',
        status: Task.statuses[:opened],
        date_delivered: Date.current,
        observation: 'Eiusmod irure est veniam commodo reprehenderit',
      }
    }

    let(:task_two) {
      {
        company:,
        software:,
        code: '1026',
        name: 'Anything',
        description: 'Laborum et culpa veniam laboris voluptate',
        date_opened: '2023-10-02',
        status: Task.statuses[:opened],
        date_delivered: Date.current,
        observation: 'Eiusmod irure est veniam commodo reprehenderit',
      }
    }

    let(:task_params_invalid) {
      {
        company: nil,
        software: nil,
        code: nil,
        name: nil,
        date_opened: nil,
        status: nil,
      }
    }

    it 'returns all tasks order date_opened desc' do
      task_record_one = create(:task, task_one)
      task_record_two = create(:task, task_two)

      get :index
      response_body = response.parsed_body
      expect(response_body.size).to eq(2)
      expect(response_body[0]['id']).to eq(task_record_two.id)
      expect(response_body[0]['dateOpened']).to eq('2023-10-02')
      expect(response_body[0]['companyName']).to eq(task_record_one.company.name)
      expect(response_body[0]['softwareName']).to eq(task_record_one.software.name)
      expect(response_body[1]['id']).to eq(task_record_one.id)
      expect(response_body[1]['dateOpened']).to eq('2023-10-01')
      expect(response_body[1]['companyName']).to eq(task_record_one.company.name)
      expect(response_body[1]['softwareName']).to eq(task_record_one.software.name)
    end

    it 'returns nil companyName and softwareName when associations are missing' do
      task_double = instance_double(
        Task,
        id: 9999,
        company: nil,
        software: nil,
        code: 'X',
        name: 'Y',
        date_opened: '2023-10-03',
        status: 'opened',
        date_delivered: nil,
        observation: nil,
        total_hours: '00:00',
      )

      allow(Task).to receive(:includes).with(:company, :software).and_return(Task)
      allow(Task).to receive(:order).with(created_at: :desc).and_return([task_double])

      get :index
      response_body = response.parsed_body
      item = response_body.find { |t| t['id'] == 9999 }
      expect(item['companyName']).to be_nil
      expect(item['softwareName']).to be_nil
    end

    it 'create action is not available for invalid params' do
      expect {
        post :create, params: { task: task_params_invalid }
      }.to raise_error(AbstractController::ActionNotFound)
    end

    it 'create action is not available for valid params' do
      company = create(:company, name: 'Company Example', value: 10)
      software = create(:software, company:, name: 'Software Example ')

      task_one[:company_id] = company.id
      task_one[:software_id] = software.id
      task_one[:status] = :opened

      expect {
        post :create, params: { task: task_one }
      }.to raise_error(AbstractController::ActionNotFound)
    end

    it 'show action is not available' do
      task = create(:task, task_one)

      expect {
        get :show, params: { id: task.id }
      }.to raise_error(AbstractController::ActionNotFound)
    end

    context 'when mark as delivered' do
      it 'marks the task as delivered without task_items and returns HTTP 200' do
        task = create(:task, task_one)

        post :mark_delivered, params: { id: task.id }

        expect(response).to have_http_status(:ok)
        task.reload
        expect(task.status).to eq('delivered')
      end

      it 'marks the task as delivered with last item task pending and returns HTTP 200' do
        task = create(:task, task_one)
        create(:task_item, task:, status: :pending)

        post :mark_delivered, params: { id: task.id }
        expect(response).to have_http_status(:ok)
        task.reload
        expect(task.status).to eq('delivered')
      end

      it 'marks the task as delivered and returns HTTP 200' do
        task = create(:task, task_one)
        create(:task_item, task:, status: :finalized)

        post :mark_delivered, params: { id: task.id }

        expect(response).to have_http_status(:ok)
        task.reload
        expect(task.status).to eq('delivered')
        expect(task.date_delivered).to eq(Date.current)
      end

      it 'returns HTTP 422 when update raises validation error' do
        task = create(:task, task_one)
        allow(Task).to receive(:find_by).and_return(task)
        allow(task).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(task))

        post :mark_delivered, params: { id: task.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to be_present
      end

      it 'returns 404 when task not found' do
        allow(Task).to receive(:find_by).and_return(nil)
        post :mark_delivered, params: { id: 123 }
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq('Task not found')
      end

      it 'renders companyName/softwareName nulos quando associações ausentes (branches &.)' do
        fake_task = instance_double(
          Task,
          id: 999,
          company: nil,
          software: nil,
          code: 'X',
          name: 'Y',
          date_opened: '2023-10-03',
          status: 'delivered',
          date_delivered: Date.current,
          observation: nil,
          total_hours: '00:00',
        )

        allow(fake_task).to receive(:update!).and_return(true)
        allow(Task).to receive(:find_by).and_return(fake_task)

        post :mark_delivered, params: { id: 999 }
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['companyName']).to be_nil
        expect(body['softwareName']).to be_nil
        expect(body['status']).to eq('delivered')
      end
    end
  end
end
