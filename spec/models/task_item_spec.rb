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
end
