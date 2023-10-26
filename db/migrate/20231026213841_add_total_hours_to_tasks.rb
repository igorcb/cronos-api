class AddTotalHoursToTasks < ActiveRecord::Migration[7.0]
  def change
    add_column :tasks, :total_hours, :string
  end
end
