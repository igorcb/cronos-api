class Task < ApplicationRecord
  belongs_to :company
  belongs_to :software

  has_many :task_items, dependent: :destroy

  validates :name, :date_opened, :status, presence: true
  validates :code, presence: true, uniqueness: { scope: %i[company_id software_id] }

  enum status: { opened: 0, finalized: 1, reopened: 2, delivered: 3 }
end
