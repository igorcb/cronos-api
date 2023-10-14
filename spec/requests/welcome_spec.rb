# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Welcome', type: :request do
  describe 'GET /' do
    it 'returns http success' do
      get '/'

      expect(response).to have_http_status(:success)
    end

    it 'returns message "Server is running"' do
      get '/'

      response_body = response.parsed_body
      expect(response_body['message']).to eq 'Server is running!!!'
    end
  end

  describe 'GET /companies' do
    let(:companies_attributes) {
      { name: 'Example' }
    }

    it 'returns http success' do
      get '/companies'

      expect(response).to have_http_status(:success)
    end

    it 'display all companies' do
      company = Company.create!(companies_attributes)

      get '/companies'

      response_json = response.parsed_body
      expect(response_json[0]['name']).to eq(company.name)
    end
  end

  describe 'GET /softwares' do
    it 'returns http success' do
      get '/softwares'

      expect(response).to have_http_status(:success)
    end

    it 'display all softwares' do
      company = Company.create!(name: 'Company Example')
      software = company.softwares.create(name: 'Software Example')

      get '/softwares'

      response_json = response.parsed_body
      expect(response_json[0]['company_id']).to eq(company.id)
      expect(response_json[0]['name']).to eq(software.name)
    end

    it 'display all software by company_id' do
      company = Company.create!(name: 'Company Example')
      software_one = company.softwares.create(name: 'Software Example - 01')
      software_two = company.softwares.create(name: 'Software Example - 02')

      get "/companies/#{company.id}/softwares"
      response_json = response.parsed_body
      expect(response_json.count).to eq(2)
      expect(response_json[0]['company_id']).to eq(company.id)
      expect(response_json[0]['name']).to eq(software_one.name)
      expect(response_json[1]['name']).to eq(software_two.name)
    end
  end
end
