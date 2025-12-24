class AddHomeBaseLocationToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_reference :companies, :home_base, type: :uuid, foreign_key: { to_table: :locations }
  end
end
