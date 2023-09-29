require 'rails_helper'

RSpec.describe Task, type: :model do
  subject(:task) {
    described_class.new(
      company:,
      software:,
      code: '1025',
      name: 'Anything',
      description: 'Laborum et culpa veniam laboris voluptate',
      date_opened: Date.current,
      status: described_class.statuses[:opened],
      date_delivered: Date.current,
      observation: 'Eiusmod irure est veniam commodo reprehenderit',
    )
  }

  let(:company) { create(:company) }
  let(:software) { company.softwares.create(name: 'Software Example') }

  let(:card) {
    {
      company:,
      software:,
      code: '1204',
      name: 'Card Example',
      date_opened: Date.current,
      status: described_class.statuses[:opened],
    }
  }

  it { is_expected.to respond_to(:company) }
  it { is_expected.to respond_to(:software) }
  it { is_expected.to respond_to(:code) }
  it { is_expected.to respond_to(:name) }
  it { is_expected.to respond_to(:description) }
  it { is_expected.to respond_to(:date_opened) }
  it { is_expected.to respond_to(:status) }
  it { is_expected.to respond_to(:date_delivered) }
  it { is_expected.to respond_to(:observation) }
  it { is_expected.to belong_to(:company) }
  it { is_expected.to belong_to(:software) }

  it 'is valid with valid attributes' do
    expect(task.valid?).to be(true)
  end

  it 'is not valid without a company' do
    task.company = nil
    expect(task.valid?).to be(false)
  end

  it 'is not valid without a software' do
    task.software = nil
    expect(task.valid?).to be(false)
  end

  it 'is not valid without a code' do
    task.code = nil
    expect(task.valid?).to be(false)
  end

  it 'is not valid without a name' do
    task.name = nil
    expect(task.valid?).to be(false)
  end

  it 'is not valid without a date_opened' do
    task.date_opened = nil
    expect(task.valid?).to be(false)
  end

  it 'is not valid without a status' do
    task.status = nil
    expect(task.valid?).to be(false)
  end

  it 'validates that the status is opened' do
    task.status = described_class.statuses[:opened]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is finalized' do
    task.status = described_class.statuses[:finalized]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is reopened' do
    task.status = described_class.statuses[:reopened]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is delivered' do
    task.status = described_class.statuses[:delivered]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is not open, closed, reopened or delivered' do
    task.status = described_class.statuses[:other]
    expect(task.valid?).not_to be(true)
  end

  it 'has a unique code for a company and software' do
    described_class.create!(card)
    software_duplicate = described_class.new(card)

    expect(software_duplicate.valid?).not_to be(true)
    expect(software_duplicate.errors[:code]).to include('has already been taken')
  end
end