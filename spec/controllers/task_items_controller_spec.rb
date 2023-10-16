require 'rails_helper'

RSpec.describe TaskItemsController, type: :controller do
  describe 'GET /tasks/:task_id/task_items' do
    let!(:task) { create(:task) }
    let(:task_item) {
      {
        date_start: '2023-10-16',
        hour_start: '09:00',
        hour_end: '10:15',
        status: TaskItem.statuses[:pending],
      }
    }

    let(:task_item_params_invalid) {
      {
        task: nil,
        date_start: nil,
        hour_start: nil,
        hour_end: nil,
        status: nil,
      }
    }

    let(:task_item_params_valid) {
      {
        date_start: '2023-10-16',
        hour_start: '10:16',
        hour_end: '11:23',
        status: :pending,
      }
    }

    it 'return all task_items from task' do
      task.task_items.create(task_item)

      get :index, params: { task_id: task.id }

      response_body = response.parsed_body

      expect(response_body.size).to eq(1)
      expect(response_body[0]['dateStart']).to eq('2023-10-16')
      expect(response_body[0]['hourStart']).to eq('09:00')
      expect(response_body[0]['hourEnd']).to eq('10:15')
      expect(response_body[0]['hourEnd']).to eq('10:15')
      expect(response_body[0]['status']).to eq('pending')
    end

    it 'when params invalid return unprocessable_entity' do
      post :create, params: { task_id: task.id, task_item: task_item_params_invalid }

      expect(response).to have_http_status(:unprocessable_entity)

      response_body = response.parsed_body
      expect(response_body).to include('date_start' => ["can't be blank"])
      expect(response_body).to include('hour_start' => ["can't be blank"])
      expect(response_body).to include('status' => ["can't be blank"])
    end

    it 'when params valid return success' do
      post :create, params: { task_id: task.id, task_item: task_item_params_valid }

      expect(response).to have_http_status(:created)
      expect(response.body).not_to include('hasErrors')

      response_body = response.parsed_body

      expect(response_body['dateStart']).to eq('2023-10-16')
      expect(response_body['hourStart']).to eq('10:16')
      expect(response_body['hourEnd']).to eq('11:23')
      expect(response_body['totalHours']).to eq('01:07')
      expect(response_body['status']).to eq('pending')
    end
  end
end