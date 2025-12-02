require 'rails_helper'

RSpec.describe TaskItemsController, type: :controller do
  let(:company) { create(:company, name: 'Example Company', value: 10) }
  let(:software) { company.softwares.create(name: 'Example Software') }
  let(:task) { Task.create(company:, software:, code: 'C01', name: 'Example', date_opened: Date.today, status: 'opened') }

  describe 'GET #index' do
    it 'retorna itens da tarefa' do
      TaskItem.create(task:, date_start: Date.today, hour_start: '08:00', hour_end: '09:00', status: 'pending')
      get :index, params: { task_id: task.id }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['task_id']).to eq(task.id)
    end
  end

  describe 'POST #create' do
    it 'cria item com sucesso' do
      post :create, params: { task_id: task.id, task_item: { date_start: Date.today, hour_start: '08:00', hour_end: '09:00', status: 'pending' } }
      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['task_id']).to eq(task.id)
    end

    it 'retorna erro quando validação falha' do
      post :create, params: { task_id: task.id, task_item: { date_start: '', hour_start: '', hour_end: '', status: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body).to include('date_start')
      expect(body).to include('hour_start')
      expect(body).to include('status')
    end
  end

  describe 'before_action set_task' do
    it 'retorna not_found quando task não existe' do
      get :index, params: { task_id: 999_999 }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('Task not found')
    end
  end
end

