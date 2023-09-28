class Company < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :softwares, dependent: :destroy
end
