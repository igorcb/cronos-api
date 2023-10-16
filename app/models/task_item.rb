class TaskItem < ApplicationRecord
  belongs_to :task

  validates :task_id, presence: true
  validates :date_start, presence: true
  validates :hour_start, presence: true
  validates :status, presence: true

  enum status: { pending: 0, finalized: 1 }

  after_save :task_update_status

  delegate :update_status, to: :task, prefix: true

  def as_json(_options = {})
    {
      id:,
      task_id:,
      dateStart: date_start,
      hourStart: time_parse(hour_start),
      hourEnd: time_parse(hour_end),
      totalHours: total_hours,
      status:,
      observation:,
    }
  end

  def total_hours
    CalculateHours.new.execute(extract_hours_task)
  end

  private

  def extract_hours_task
    [
      [time_parse(hour_start), time_parse(hour_end)],
    ]
  end

  def time_parse(time)
    time.to_time.strftime('%H:%M')
  end
end
