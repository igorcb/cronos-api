class TaskItem < ApplicationRecord
  belongs_to :task

  validates :task_id, presence: true
  validates :date_start, presence: true
  validates :hour_start, presence: true
  validates :status, presence: true

  enum status: { pending: 0, finalized: 1 }

  after_save :task_update_status

  delegate :update_status, to: :task, prefix: true
end
