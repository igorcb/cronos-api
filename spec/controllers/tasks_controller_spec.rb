require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:company) { create(:company, name: 'Example Company', value: 10) }
  let(:software) { company.softwares.create(name: 'Example Software') }

  describe 'GET #index' do
    it 'lists tasks with mapped fields' do
      task = Task.create(company:, software:, code: 'C01', name: 'Example', date_opened: Time.zone.today, status: 'opened')
      get :index
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['id']).to eq(task.id)
      expect(body.first['companyName']).to eq(company.name)
      expect(body.first['softwareName']).to eq(software.name)
      expect(body.first['status']).to eq('opened')
    end

    it 'serializes with companyName and softwareName null when associations missing' do
      task = Task.create(company:, software:, code: 'C99', name: 'Nil Assoc', date_opened: Time.zone.today, status: 'opened')
      allow(Task).to receive_messages(includes: Task, order: [task])
      allow(task).to receive_messages(company: nil, software: nil)
      get :index
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.first['companyName']).to be_nil
      expect(body.first['softwareName']).to be_nil
    end
  end

  describe 'POST #mark_delivered' do
    it 'updates status to delivered' do
      task = Task.create(company:, software:, code: 'C02', name: 'Deliver', date_opened: Time.zone.today, status: 'opened')
      post :mark_delivered, params: { id: task.id }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['status']).to eq('delivered')
      expect(body['dateDelivered']).to eq(Date.current.to_s)
    end

    it 'returns not_found when task does not exist' do
      post :mark_delivered, params: { id: 999_999 }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('Task not found')
    end

    it 'returns error when update is invalid' do
      task = Task.create(company:, software:, code: 'C03', name: 'Err', date_opened: Time.zone.today, status: 'opened')
      allow(Task).to receive(:find_by).with(id: task.id).and_return(task)
      allow(Task).to receive(:find_by).with(id: task.id.to_s).and_return(task)
      allow(task).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(task))
      post :mark_delivered, params: { id: task.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to be_present
    end

    it 'serializes companyName and softwareName as null when associations missing' do
      task = Task.create(company:, software:, code: 'C04', name: 'Nil Assoc', date_opened: Time.zone.today, status: 'opened')
      task.task_items.create(date_start: Time.zone.today, hour_start: '08:00', hour_end: '09:00', status: 'finalized')
      allow(Task).to receive(:find_by).with(id: task.id).and_return(task)
      allow(Task).to receive(:find_by).with(id: task.id.to_s).and_return(task)
      allow(task).to receive(:update!).and_wrap_original do |m, *args|
        m.call(*args)
      end
      allow(task).to receive(:company).and_return(company, nil)
      allow(task).to receive(:software).and_return(software, nil)

      post :mark_delivered, params: { id: task.id }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['companyName']).to be_nil
      expect(body['softwareName']).to be_nil
    end
  end
end
