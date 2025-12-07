class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers, id: :uuid do |t|
      t.string :first_name
      t.string :last_name
      t.string :company_name
      t.string :billing_email
      t.string :phone

      t.timestamps
    end

    add_index :customers, :company_name
    add_index :customers, :last_name
  end
end
