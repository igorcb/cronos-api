require 'rails_helper'

RSpec.describe TaskItemsController, type: :controller do
  let(:company) { create(:company, name: 'Example Company', value: 10) }
  let(:software) { company.softwares.create(name: 'Example Software') }
  let(:task) { Task.create(company:, software:, code: 'C01', name: 'Example', date_opened: Time.zone.today, status: 'opened') }

  describe 'GET #index' do
    it 'returns task items' do
      TaskItem.create(task:, date_start: Time.zone.today, hour_start: '08:00', hour_end: '09:00', status: 'pending')
      get :index, params: { task_id: task.id }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['task_id']).to eq(task.id)
    end
  end

  describe 'POST #create' do
    it 'creates item successfully' do
      post :create, params: { task_id: task.id, task_item: { date_start: Time.zone.today, hour_start: '08:00', hour_end: '09:00', status: 'pending' } }
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['task_id']).to eq(task.id)
    end

    it 'returns error when validation fails' do
      post :create, params: { task_id: task.id, task_item: { date_start: '', hour_start: '', hour_end: '', status: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body).to include('date_start')
      expect(body).to include('hour_start')
      expect(body).to include('status')
    end

    it 'accepts dd/mm/yyyy format and saves correctly' do
      post :create, params: { task_id: task.id, task_item: { date_start: '25/11/2003', hour_start: '12:56', hour_end: '11:48', status: 'pending' } }
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['dateStart']).to eq('2003-11-25')
    end

    it 'accepts ISO yyyy-mm-dd' do
      post :create, params: { task_id: task.id, task_item: { date_start: '2004-11-25', hour_start: '09:32', hour_end: '07:01', status: 'pending' } }
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['dateStart']).to eq('2004-11-25')
    end

    it 'rejects invalid date' do
      post :create, params: { task_id: task.id, task_item: { date_start: '25/13/2003', hour_start: '10:00', hour_end: '11:00', status: 'pending' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body).to include('date_start')
    end
  end

  describe 'before_action set_task' do
    it 'returns not_found when task does not exist' do
      get :index, params: { task_id: 999_999 }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('Task not found')
    end
  end
end
