require 'rails_helper'

RSpec.describe CalculateTotalHours do
  describe '#execute' do
    subject(:calculate) {
      described_class.new
    }

    let(:hours_empty) {
      []
    }

    let(:hours_valid) {
      ['09:02', '13:35', '03:31']
    }

    let(:sixty_minute) {
      ['09:60']
    }

    let(:less_than_sixty_minute) {
      ['09:50']
    }

    let(:great_than_sixty_minute) {
      ['09:61']
    }

    it 'when you have not informed times ' do
      expect(calculate.execute(hours_empty)).to eq('00:00')
    end

    it 'when you have informed times valid' do
      expect(calculate.execute(hours_valid)).to eq('26:08')
    end

    it 'when you have informed less than sixty minute' do
      expect(calculate.execute(less_than_sixty_minute)).to eq('09:50')
    end

    it 'when you have informed sixty minute' do
      expect(calculate.execute(sixty_minute)).to eq('10:00')
    end

    it 'when you have informed great than sixty minute' do
      expect(calculate.execute(great_than_sixty_minute)).to eq('10:01')
    end
  end
end