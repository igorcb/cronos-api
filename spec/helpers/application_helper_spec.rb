require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#page_title' do
    it 'returns the instance variable' do
      assign(:title, 'My Title')
      expect(helper.page_title).to eql('My Title')
    end
  end
end
