require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:company) { create(:company, name: 'Example Company', value: 10) }
  let(:software) { company.softwares.create(name: 'Example Software') }

  describe 'GET #index' do
    it 'lista tasks com campos mapeados' do
      task = Task.create(company:, software:, code: 'C01', name: 'Example', date_opened: Date.today, status: 'opened')
      get :index
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['id']).to eq(task.id)
      expect(body.first['companyName']).to eq(company.name)
      expect(body.first['softwareName']).to eq(software.name)
      expect(body.first['status']).to eq('opened')
    end

    it 'serializa com companyName e softwareName nulos quando associações faltam' do
      task = Task.create(company:, software:, code: 'C99', name: 'Nil Assoc', date_opened: Date.today, status: 'opened')
      allow(Task).to receive(:includes).and_return(Task)
      allow(Task).to receive(:order).and_return([task])
      allow(task).to receive_messages(company: nil, software: nil)
      get :index
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['companyName']).to be_nil
      expect(body.first['softwareName']).to be_nil
    end
  end

  describe 'POST #mark_delivered' do
    it 'atualiza status para delivered' do
      task = Task.create(company:, software:, code: 'C02', name: 'Deliver', date_opened: Date.today, status: 'opened')
      post :mark_delivered, params: { id: task.id }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['status']).to eq('delivered')
      expect(body['dateDelivered']).to eq(Date.current.to_s)
    end

    it 'retorna not_found quando tarefa não existe' do
      post :mark_delivered, params: { id: 999_999 }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('Task not found')
    end

    it 'retorna erro quando update inválido' do
      task = Task.create(company:, software:, code: 'C03', name: 'Err', date_opened: Date.today, status: 'opened')
      allow(Task).to receive(:find_by).with(id: task.id).and_return(task)
      allow(Task).to receive(:find_by).with(id: task.id.to_s).and_return(task)
      allow(task).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(task))
      post :mark_delivered, params: { id: task.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to be_present
    end
  end
end
