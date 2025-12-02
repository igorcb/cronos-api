require 'rails_helper'

RSpec.describe CalculateTotalHours do
  describe '#execute' do
    it 'retorna 00:00 quando vazio' do
      expect(described_class.new.execute([])).to eq('00:00')
    end

    it 'soma horas e minutos sem carry' do
      expect(described_class.new.execute(%w[01:10 02:20])).to eq('03:30')
    end

    it 'faz carry quando minutos >= 60' do
      expect(described_class.new.execute(%w[00:50 00:15 00:10])).to eq('01:15')
    end

    it 'acumula vários tempos' do
      expect(described_class.new.execute(%w[00:30 00:30 01:00 02:15])).to eq('04:15')
    end
  end
end

