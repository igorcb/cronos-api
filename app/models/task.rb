class Task < ApplicationRecord
  belongs_to :company
  belongs_to :software

  has_many :task_items, dependent: :destroy

  validates :company, :software, :name, :date_opened, :status, presence: true
  validates :code, presence: true, uniqueness: { scope: %i[company_id software_id] }

  enum :status, { opened: 0, finalized: 1, reopened: 2, delivered: 3 }

  def as_json(_options = {})
    {
      id:,
      companyName: company&.name,
      softwareName: software&.name,
      code:,
      name:,
      dateOpened: date_opened,
      status:,
      dateDelivered: date_delivered,
      totalHours: total_hours,
      observation:,
    }
  end

  def self.finalized_or_delivered
    where(status: %i[finalized delivered])
  end

  def self.opened_or_reopened
    where(status: %i[opened reopened])
  end

  def self.total_hours_tasks
    hours = Task.pluck(:total_hours)
    CalculateTotalHours.new.execute(hours)
  end

  def self.total_count_tasks
    Task.count
  end

  def self.total_value_tasks
    value = Company.first.value.to_f

    hours, minutes = Task.total_hours_tasks.split(':')
    total_minutes = (value / 60) * minutes.to_f
    (hours.to_f * value) + total_minutes.round(2)
  end

  def self.total_hours_tasks_finalized_or_delivered
    hours = Task.finalized_or_delivered.pluck(:total_hours)
    CalculateTotalHours.new.execute(hours)
  end

  def self.total_count_tasks_finalized_or_delivered
    Task.finalized_or_delivered.count
  end

  def self.total_value_tasks_finalized_or_delivered
    value = Company.first.value.to_f

    hours, minutes = Task.finalized_or_delivered.total_hours_tasks.split(':')
    total_minutes = (value / 60) * minutes.to_f
    (hours.to_f * value) + total_minutes.round(2)
  end

  def self.total_hours_tasks_opened_or_reopened
    hours = Task.opened_or_reopened.pluck(:total_hours)
    CalculateTotalHours.new.execute(hours)
  end

  def self.total_count_tasks_opened_or_reopened
    Task.opened_or_reopened.count
  end

  def self.total_value_tasks_opened_or_reopened
    value = Company.first.value.to_f

    hours, minutes = Task.opened_or_reopened.total_hours_tasks.split(':')
    total_minutes = (value / 60) * minutes.to_f
    (hours.to_f * value) + total_minutes.round(2)
  end

  def self.total_count_tasks_delivered
    where(status: :delivered).count
  end

  def self.total_hours_tasks_delivered
    hours = where(status: :delivered).pluck(:total_hours)
    CalculateTotalHours.new.execute(hours)
  end

  def self.total_value_tasks_delivered
    value = Company.first.value.to_f

    hours, minutes = total_hours_tasks_delivered.split(':')
    total_minutes = (value / 60) * minutes.to_f
    (hours.to_f * value) + total_minutes.round(2)
  end

  def software
    Software.where(id: software_id).first
  end

  def update_status
    return 'opened' if task_items.blank?

    if task_items.last.finalized?
      update(status: 'finalized', total_hours: total_hours_task_items)
    else
      update(status: 'reopened', total_hours: total_hours_task_items)
    end
  end

  def total_hours_task_items
    CalculateHours.new.execute(extract_hours_task)
  end

  def mark_as_delivery
    msg_items = 'Cannot mark a task as delivered because it has no task_item'
    msg_finalized = 'The status of the last task is not finished'

    return errors.add(:base, msg_items) if task_items.blank?
    return errors.add(:base, msg_finalized) unless task_items.last.finalized?

    update(status: :delivered, date_delivered: Date.current)
  end

  private

  def extract_hours_task
    task_items.map do |task_item|
      start_time = task_item.time_parse(task_item.hour_start)
      end_time = task_item.time_parse(task_item.hour_end)
      next if start_time.to_s.strip.empty? || end_time.to_s.strip.empty?

      [start_time, end_time]
    end.compact
  end
end
