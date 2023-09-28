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
end
