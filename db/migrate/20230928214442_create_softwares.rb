class CreateSoftwares < ActiveRecord::Migration[7.0]
  def change
    create_table :softwares do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
    add_index(
      :softwares, 
      [:company_id, :name], 
      unique: true,
      name: "idx_softwares_on_company_id_and_name_uniq"
    )
  end
end
