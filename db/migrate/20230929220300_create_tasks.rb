class CreateTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks do |t|
      t.references :company, null: false, foreign_key: true
      t.references :software, null: false, foreign_key: true
      t.string :code
      t.string :name
      t.text :description
      t.date :date_opened
      t.integer :status
      t.date :date_delivered
      t.text :observation

      t.timestamps
    end
    add_index(
      :tasks, 
      [:company_id, :software_id, :code], 
      unique: true,
      name: "idx_card_on_company_id_and_software_and_code_uniq"
    )

  end
end
