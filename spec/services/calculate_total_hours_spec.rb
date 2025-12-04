require 'rails_helper'

RSpec.describe CalculateTotalHours do
  describe '#execute' do
    it 'returns 00:00 when empty' do
      expect(described_class.new.execute([])).to eq('00:00')
    end

    it 'sums hours and minutes without carry' do
      expect(described_class.new.execute(%w[01:10 02:20])).to eq('03:30')
    end

    it 'does carry when minutes >= 60' do
      expect(described_class.new.execute(%w[00:50 00:15 00:10])).to eq('01:15')
    end

    it 'accumulates multiple times' do
      expect(described_class.new.execute(%w[00:30 00:30 01:00 02:15])).to eq('04:15')
    end
  end
end
