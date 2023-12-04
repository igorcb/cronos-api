class AddValueToCompany < ActiveRecord::Migration[7.0]
  def change
    add_column :companies, :value, :decimal, precision: 10, scale: 2
  end
end
