require 'rails_helper'

RSpec.describe Company, type: :model do
  subject(:company) { described_class.new(name: 'Anything') }

  it { is_expected.to respond_to(:name) }
  it { is_expected.to have_many(:softwares) }

  it 'is valid with valid attributes' do
    expect(company.valid?).to be(true)
  end

  it 'is not valid without a name' do
    company.name = nil
    expect(company.valid?).to be(false)
  end

  it 'has a unique name' do
    described_class.create!(name: 'Example')
    company_duplicate = described_class.new(name: 'Example')
    expect(company_duplicate.valid?).not_to be(true)
    expect(company_duplicate.errors[:name]).to include('has already been taken')
  end
end
