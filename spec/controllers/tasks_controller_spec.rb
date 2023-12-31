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

    it 'when params invalid return unprocessable_entity' do
      post :create, params: { task: task_params_invalid }

      expect(response).to have_http_status(:unprocessable_entity)

      response_body = response.parsed_body
      expect(response_body).to include('company' => ['must exist'])
      expect(response_body).to include('software' => ['must exist'])
      expect(response_body).to include('name' => ["can't be blank"])
      expect(response_body).to include('date_opened' => ["can't be blank"])
      expect(response_body).to include('status' => ["can't be blank"])
      expect(response_body).to include('code' => ["can't be blank"])
    end

    it 'when params valid return success' do
      company = create(:company, name: 'Company Example', value: 10)
      software = create(:software, company:, name: 'Software Example ')

      task_one[:company_id] = company.id
      task_one[:software_id] = software.id
      task_one[:status] = :opened

      post :create, params: { task: task_one }

      expect(response).to have_http_status(:created)
      expect(response.body).not_to include('hasErrors')

      response_body = response.parsed_body
      expect(response_body['code']).to eq('1025')
      expect(response_body['name']).to eq('Anything')
      expect(response_body['dateOpened']).to eq('2023-10-01')
      expect(response_body['status']).to eq('opened')
    end

    it 'must return data from a task' do
      task = create(:task, task_one)

      get :show, params: { id: task.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('hasErrors')

      response_body = response.parsed_body
      expect(response_body['code']).to eq('1025')
      expect(response_body['name']).to eq('Anything')
      expect(response_body['dateOpened']).to eq('2023-10-01')
      expect(response_body['status']).to eq('opened')
      expect(response_body['totalHours']).to eq('00:00')
    end

    context 'when mark as delivered' do
      it 'does not mark the task delivery without task_items and returns HTTP 422' do
        msg = 'Cannot mark a task as delivered because it has no task_item'
        task = create(:task, task_one)

        post :mark_delivered, params: { id: task.id }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to include(msg)
        expect(task.status).not_to eq('delivered')
      end

      it 'does not marks the task as delivered with last item task is pending returns HTTP 422' do
        msg = 'The status of the last task is not finished'
        task = create(:task, task_one)
        create(:task_item, task:, status: :pending)

        post :mark_delivered, params: { id: task.id }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to include(msg)
        expect(task.status).not_to eq('delivered')
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
    end
  end
end
