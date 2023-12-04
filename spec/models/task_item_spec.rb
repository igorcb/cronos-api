require 'rails_helper'

RSpec.describe TaskItem, type: :model do
  subject(:task_item) {
    described_class.new(
      task:,
      date_start: '2023-10-04',
      hour_start: Time.zone.parse('15:30:00'),
      date_end: '2023-10-04',
      hour_end: Time.zone.parse('16:30:00'),
      status: described_class.statuses[:pending],
      observation: 'Culpa id culpa id dolor nostrud labore aute et qui eiusmod proident id.',
    )
  }

  let(:task) { create(:task) }
  let(:task_items_attributes) {
    {
      date_start: '2023-10-04',
      hour_start: '2023-10-04 19:43:37',
      date_end: '2023-10-04',
      hour_end: '2023-10-04 19:47:37',
    }
  }

  it { is_expected.to respond_to(:task) }
  it { is_expected.to respond_to(:date_start) }
  it { is_expected.to respond_to(:hour_start) }
  it { is_expected.to respond_to(:date_end) }
  it { is_expected.to respond_to(:hour_end) }
  it { is_expected.to respond_to(:status) }
  it { is_expected.to respond_to(:observation) }
  it { is_expected.to belong_to(:task) }

  it 'is valid with valid attributes' do
    expect(task_item.valid?).to be(true)
  end

  it 'is not valid without a task' do
    task_item.task = nil
    expect(task_item.valid?).to be(false)
  end

  it 'is not valid without a date_start' do
    task_item.date_start = nil
    expect(task_item.valid?).to be(false)
  end

  it 'is not valid without a hour_start' do
    task_item.hour_start = nil
    expect(task_item.valid?).to be(false)
  end

  it 'is not valid without a status' do
    task_item.status = nil
    expect(task_item.valid?).to be(false)
  end

  it 'validates that the status is pending' do
    task.status = described_class.statuses[:pending]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is finalized' do
    task.status = described_class.statuses[:finalized]
    expect(task.valid?).to be(true)
  end

  it 'validates that the status is not pending, finalized' do
    task.status = described_class.statuses[:other]
    expect(task.valid?).not_to be(true)
  end

  it 'when without task item is finalized set the task status to opened' do
    company = create(:company, name: 'Example Company', value: 10)
    software = company.softwares.create(name: 'Example Software')
    task = create(
      :task,
      name: 'Example Task',
      date_opened: Date.current,
      status: Task.statuses[:opened],
      company:,
      software:,
    )

    expect(task.status).to eq('opened')

    task.update_status
    task.reload

    expect(task.status).to eq('opened')
  end

  it 'when the status of the last task item is finalized set the task status to finalized' do
    company = create(:company, name: 'Example Company', value: 10)
    software = company.softwares.create(name: 'Example Software')
    task = create(
      :task,
      name: 'Example Task',
      date_opened: Date.current,
      status: Task.statuses[:opened],
      company:,
      software:,
    )

    create(:task_item, task:, status: Task.statuses[:finalized])

    expect(task.status).to eq('finalized')

    task.update_status
    task.reload

    expect(task.status).to eq('finalized')
    expect(task.total_hours).to eq('00:04')
  end

  context 'when creating an item from a completed task' do
    it 'must have a reopened task status' do
      company = create(:company, name: 'Example Company', value: 10)
      software = company.softwares.create(name: 'Example Software')
      task = create(
        :task,
        name: 'Example Task',
        date_opened: Date.current,
        status: Task.statuses[:opened],
        company:,
        software:,
      )

      task_items_attributes[:status] = described_class.statuses[:finalized]
      task.task_items.create(task_items_attributes)
      task.reload

      task_items_attributes[:status] = described_class.statuses[:pending]
      task.task_items.create(task_items_attributes)
      task.reload

      expect(task.status).to eq('reopened')
    end
  end

  it 'time parse' do
    hour = task_item.time_parse(task_item.hour_end)
    expect(hour).to eq('16:30')
  end
end
