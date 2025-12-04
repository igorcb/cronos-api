require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#page_title' do
    it 'returns nil when @title is not set' do
      expect(helper.page_title).to be_nil
    end

    it 'returns @title when set' do
      helper.instance_variable_set(:@title, 'Dashboard')
      expect(helper.page_title).to eq('Dashboard')
    end
  end
end
