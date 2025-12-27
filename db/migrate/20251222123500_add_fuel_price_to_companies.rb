class AddFuelPriceToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :fuel_price_per_gallon, :decimal, precision: 8, scale: 3
  end
end
