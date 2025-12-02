require 'rails_helper'

RSpec.describe WelcomeController, type: :controller do
  describe 'GET #index' do
    it 'retorna mensagem de status' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['message']).to eq('Server is running!!!')
    end
  end

  describe 'GET #companies' do
    it 'lista empresas ordenadas' do
      create(:company, name: 'B', value: 10)
      create(:company, name: 'A', value: 10)
      get :companies
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |c| c['name'] }).to eq(%w[A B])
    end
  end

  describe 'GET #softwares' do
    it 'lista softwares com company' do
      c = create(:company, name: 'C', value: 10)
      s = c.softwares.create(name: 'S')
      get :softwares
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first['name']).to eq('S')
    end
  end

  describe 'GET #softwares_by_company_id' do
    it 'lista softwares por empresa' do
      c = create(:company, name: 'C', value: 10)
      c.softwares.create(name: 'S1')
      c.softwares.create(name: 'S2')
      get :softwares_by_company_id, params: { company_id: c.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(2)
    end
  end

  describe 'GET #dashboard' do
    it 'retorna métricas do dashboard e no-store' do
      c = create(:company, value: 10)
      s = c.softwares.create(name: 'S')
      t = Task.create(company: c, software: s, code: 'C01', name: 'T', date_opened: Date.today, status: 'opened')
      t.task_items.create(date_start: Date.today, hour_start: '08:00', hour_end: '09:00', status: 'finalized')
      get :dashboard
      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to eq('no-store')
      body = response.parsed_body
      expect(body['totalCards']).to be_a(Integer)
    end
  end
end
