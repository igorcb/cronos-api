require 'rails_helper'

RSpec.describe CalculateHours do
  describe '#execute' do
    it 'returns 00:00 when hours empty' do
      expect(described_class.new.execute([])).to eq('00:00')
    end

    it 'sums a single valid pair' do
      expect(described_class.new.execute([['08:00', '09:30']])).to eq('01:30')
    end

    it 'ignores pairs with missing start or end' do
      expect(described_class.new.execute([[nil, '09:00'], ['08:00', nil]])).to eq('00:00')
    end

    it 'ignores non-positive intervals' do
      expect(described_class.new.execute([['10:00', '09:00'], ['08:00', '08:00']])).to eq('00:00')
    end

    it 'accumulates multiple pairs and converts minutes to hours' do
      expect(described_class.new.execute([['08:00', '08:30'], ['09:15', '10:45']])).to eq('02:00')
    end
  end
end

