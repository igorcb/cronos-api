class Company < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :value, presence: true

  has_many :softwares, dependent: :destroy
end
