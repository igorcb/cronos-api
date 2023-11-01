class Upload < ApplicationRecord
  enum status: { processing: 0, completed: 1, failed: 2 }
end
