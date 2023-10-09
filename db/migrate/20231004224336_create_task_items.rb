class CreateTaskItems < ActiveRecord::Migration[7.0]
  def change
    create_table :task_items do |t|
      t.references :task, null: false, foreign_key: true
      t.date :date_start, null: false 
      t.time :hour_start, null: false
      t.date :date_end
      t.time :hour_end
      t.integer :status, null: false
      t.text :observation

      t.timestamps
    end
  end
end
