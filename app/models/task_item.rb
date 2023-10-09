class TaskItem < ApplicationRecord
  belongs_to :task

  validates :task, presence: true
  validates :date_start, presence: true
  validates :hour_start, presence: true
  validates :status, presence: true

  enum status: { pending: 0, finalized: 1 }
end
