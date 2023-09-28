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
end
