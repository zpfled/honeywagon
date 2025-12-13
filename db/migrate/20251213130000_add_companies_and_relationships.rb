class AddCompaniesAndRelationships < ActiveRecord::Migration[8.1]
  class CompanyRecord < ApplicationRecord
    self.table_name = 'companies'
  end

  def up
    create_table :companies, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_column :users, :company_id, :uuid
    add_column :unit_types, :company_id, :uuid
    add_column :units, :company_id, :uuid
    add_column :orders, :company_id, :uuid

    add_index :users, :company_id
    add_index :unit_types, :company_id
    add_index :units, :company_id
    add_index :orders, :company_id

    add_foreign_key :users, :companies
    add_foreign_key :unit_types, :companies
    add_foreign_key :units, :companies
    add_foreign_key :orders, :companies

    CompanyRecord.reset_column_information
    default_company = CompanyRecord.create!(name: 'Demo Company')

    %i[users unit_types units orders].each do |table|
      execute <<~SQL.squish
        UPDATE #{table}
           SET company_id = '#{default_company.id}'
        WHERE company_id IS NULL
      SQL
    end

    change_column_null :users, :company_id, false
    change_column_null :unit_types, :company_id, false
    change_column_null :units, :company_id, false
    change_column_null :orders, :company_id, false
  end

  def down
    remove_foreign_key :orders, :companies
    remove_foreign_key :units, :companies
    remove_foreign_key :unit_types, :companies
    remove_foreign_key :users, :companies

    remove_index :orders, :company_id
    remove_index :units, :company_id
    remove_index :unit_types, :company_id
    remove_index :users, :company_id

    remove_column :orders, :company_id
    remove_column :units, :company_id
    remove_column :unit_types, :company_id
    remove_column :users, :company_id

    drop_table :companies
  end
end
