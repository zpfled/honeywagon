class ChangeCompanyFuelPriceToCents < ActiveRecord::Migration[8.1]
  class MigrationCompany < ApplicationRecord
    self.table_name = "companies"
  end

  def up
    add_column :companies, :fuel_price_per_gal_cents, :integer, null: false, default: 0

    MigrationCompany.reset_column_information

    if MigrationCompany.column_names.include?("fuel_price_per_gallon")
      MigrationCompany.find_each do |company|
        next if company[:fuel_price_per_gallon].nil?

        cents = (BigDecimal(company[:fuel_price_per_gallon].to_s) * 100).round
        company.update_column(:fuel_price_per_gal_cents, cents)
      end
    end

    remove_column :companies, :fuel_price_per_gallon, :decimal, precision: 8, scale: 3
  end

  def down
    add_column :companies, :fuel_price_per_gallon, :decimal, precision: 8, scale: 3

    MigrationCompany.reset_column_information

    MigrationCompany.find_each do |company|
      next if company[:fuel_price_per_gal_cents].nil?

      dollars = BigDecimal(company[:fuel_price_per_gal_cents].to_s) / 100
      company.update_column(:fuel_price_per_gallon, dollars)
    end

    remove_column :companies, :fuel_price_per_gal_cents
  end
end
