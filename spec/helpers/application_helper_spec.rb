require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#page_title' do
    it 'retorna nil quando @title não está definido' do
      expect(helper.page_title).to be_nil
    end

    it 'retorna @title quando definido' do
      helper.instance_variable_set(:@title, 'Dashboard')
      expect(helper.page_title).to eq('Dashboard')
    end
  end
end

