class AddDisplayNameToCustomers < ActiveRecord::Migration[8.1]
  class Customer < ApplicationRecord
    self.table_name = "customers"
  end

  def up
    add_column :customers, :display_name, :string

    say_with_time "Backfilling customer display names" do
      Customer.reset_column_information

      Customer.find_each do |customer|
        display_name = customer.company_name.presence
        name_from_person = [ customer.first_name, customer.last_name ].compact.join(" ").presence
        display_name ||= name_from_person
        display_name ||= customer.billing_email
        display_name ||= "Customer #{customer.id}"

        customer.update_columns(display_name: display_name)
      end
    end

    change_column_null :customers, :display_name, false
    add_index :customers, :display_name
  end

  def down
    remove_index :customers, :display_name
    remove_column :customers, :display_name
  end
end
