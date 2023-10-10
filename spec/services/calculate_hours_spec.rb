require 'rails_helper'

RSpec.describe CalculateHours do
  describe '#execute' do
    subject(:calculate) {
      described_class.new
    }

    let(:hours_empty) { [] }

    let(:one_hour_valid) {
      [
        ['07:02', '09:19'],
      ]
    }

    let(:more_hour_valid) {
      [
        ['07:02', '09:19'],
        ['11:02', '12:40'],
        ['13:57', '15:19'],
        ['07:00', '08:33'],
      ]
    }

    it 'when you have not informed the start and end times' do
      expect(calculate.execute(hours_empty)).to eq('00:00')
    end

    it 'when you have informed the start and end times' do
      expect(calculate.execute(one_hour_valid)).to eq('02:17')
    end

    it 'when you have informed the varios start and end times' do
      expect(calculate.execute(more_hour_valid)).to eq('06:50')
    end
  end
end
