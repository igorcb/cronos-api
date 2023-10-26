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
  it { is_expected.to have_many(:task_items) }

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

  it 'total hours of a task without item' do
    task = described_class.create!(card)

    expect(task.total_hours_tasks).to eq('00:00')
  end

  it 'total hours of a task with one item' do
    task = described_class.create!(card)

    task.task_items.create(
      date_start: '2023-10-04',
      hour_start: '2023-10-04 19:43:37',
      date_end: '2023-10-04',
      hour_end: '2023-10-04 19:47:37',
      status: 'pending',
      task:,
    )

    expect(task.total_hours_tasks).to eq('00:04')
  end

  it 'total hours of a task with one item invalid' do
    task = described_class.create!(card)

    task.task_items.create(
      date_start: '2023-10-04',
      hour_start: '2023-10-04 19:43:37',
      date_end: '2023-10-04',
      hour_end: '',
      status: 'pending',
      task:,
    )

    expect(task.total_hours_tasks).to eq('00:00')
  end

  it 'total hours of a task with more than one item' do
    task = described_class.create!(card)

    task.task_items.create(
      date_start: '2023-10-04',
      hour_start: '2023-10-04 19:43:37',
      date_end: '2023-10-04',
      hour_end: '2023-10-04 19:47:37',
      status: 'pending',
    )

    task.task_items.create(
      date_start: '2023-10-04',
      hour_start: '2023-10-04 19:48:37',
      date_end: '2023-10-04',
      hour_end: '2023-10-04 20:11:37',
      status: 'pending',
    )

    expect(task.total_hours_tasks).to eq('00:27')
  end

  context 'when mark as delivered' do
    it 'when there is no task_items return an error' do
      msg = 'Cannot mark a task as delivered because it has no task_item'
      task.mark_as_delivery

      expect(task.errors.messages[:base]).to include(msg)
    end

    it 'when the last item of the task is not finalized' do
      task = described_class.create!(card)

      task.task_items.create(
        date_start: '2023-10-04',
        hour_start: '2023-10-04 19:43:37',
        date_end: '2023-10-04',
        hour_end: '2023-10-04 19:47:37',
        status: 'pending',
      )

      task.mark_as_delivery

      expect(task.errors[:base]).to include('The status of the last task is not finished')
    end

    it 'mark task as delivered and date_delivered' do
      task = described_class.create!(card)

      task.task_items.create(
        date_start: '2023-10-04',
        hour_start: '2023-10-04 19:43:37',
        date_end: '2023-10-04',
        hour_end: '2023-10-04 19:47:37',
        status: 'finalized',
      )

      task.mark_as_delivery

      expect(task.errors[:base]).to be_empty
      expect(task).to be_valid
      expect(task.status).to eq('delivered')
      expect(task.date_delivered).to eq(Date.current)
    end
  end
end
