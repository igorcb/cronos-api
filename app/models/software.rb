class Software < ApplicationRecord
  belongs_to :company

  validates :company, presence: true
  validates :name, presence: true, uniqueness: { scope: :company_id }
end
