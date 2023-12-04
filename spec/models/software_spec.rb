require 'rails_helper'

RSpec.describe Software, type: :model do
  subject(:software) {
    described_class.new(company:, name: 'Anything')
  }

  let(:company) { create(:company, value: 10) }

  it { is_expected.to respond_to(:company) }
  it { is_expected.to respond_to(:name) }
  it { is_expected.to belong_to(:company) }

  it 'is valid with valid attributes' do
    expect(software.valid?).to be(true)
  end

  it 'is not valid without a company' do
    software.company = nil
    expect(software.valid?).to be(false)
  end

  it 'is not valid without a name' do
    software.name = nil
    expect(software.valid?).to be(false)
  end

  it 'has a unique name for a company' do
    described_class.create!(company:, name: 'Example')
    software_duplicate = described_class.new(company:, name: 'Example')
    expect(software_duplicate.valid?).not_to be(true)
    expect(software_duplicate.errors[:name]).to include('has already been taken')
  end
end
