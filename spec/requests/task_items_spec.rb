require 'rails_helper'

RSpec.describe 'TaskItems', type: :request do
  describe 'GET /tasks/:task_id/task_items' do
    it 'returns http success' do
      task = create(:task)
      get "/tasks/#{task.id}/task_items"
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /tasks/:task_id/task_items' do
    let!(:task) { create(:task) }

    let(:task_item) {
      {
        task_id: task.id,
        date_start: '2023-10-16',
        hour_start: '09:10',
        hour_end: '10:10',
        status: 'pending',
        observation: 'Observation text',
      }
    }

    it 'returns http success' do
      post "/tasks/#{task.id}/task_items", params: { task_item: }
      expect(response).to have_http_status(:success)
    end
  end
end
