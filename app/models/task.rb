class Task < ApplicationRecord
  belongs_to :company
  belongs_to :software

  has_many :task_items, dependent: :destroy

  validates :name, :date_opened, :status, presence: true
  validates :code, presence: true, uniqueness: { scope: %i[company_id software_id] }

  enum status: { opened: 0, finalized: 1, reopened: 2, delivered: 3 }

  def as_json(_options = {})
    {
      id:,
      companyName: company.name,
      softwareName: software.name,
      code:,
      name:,
      dateOpened: date_opened,
      status:,
      observation:,
    }
  end

  def software
    Software.where(id: software_id).first
  end

  def update_status
    return 'opened' if task_items.blank?

    if task_items.last.finalized?
      update(status: 'finalized')
    else
      update(status: 'reopened')
    end
  end

  def total_hours
    CalculateHours.new.execute(extract_hours_task)
  end

  private

  def extract_hours_task
    task_items.map do |task_item|
      hour_start = task_item.hour_start
      hour_end = task_item.hour_end

      start_time = format('%<hour>02d:%<minute>02d', hour: hour_start.hour, minute: hour_start.min)
      end_time = format('%<hour>02d:%<minute>02d', hour: hour_end.hour, minute: hour_end.min)

      [start_time, end_time]
    end
  end
end
