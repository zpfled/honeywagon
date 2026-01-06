class AddCapacityFieldsToUnitTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_types, :delivery_clean_gallons, :integer, null: false, default: 0
    add_column :unit_types, :service_clean_gallons, :integer, null: false, default: 0
    add_column :unit_types, :service_waste_gallons, :integer, null: false, default: 0
    add_column :unit_types, :pickup_clean_gallons, :integer, null: false, default: 0
    add_column :unit_types, :pickup_waste_gallons, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        UnitType.reset_column_information
        UnitType.find_each do |unit_type|
          defaults = default_capacity_settings(unit_type.slug)
          unit_type.update_columns(defaults)
        end
      end
    end
  end

  def default_capacity_settings(slug)
    case slug
    when 'handwash'
      {
        delivery_clean_gallons: 20,
        service_clean_gallons: 7,
        service_waste_gallons: 10,
        pickup_clean_gallons: 2,
        pickup_waste_gallons: 10
      }
    else
      {
        delivery_clean_gallons: 5,
        service_clean_gallons: 7,
        service_waste_gallons: 10,
        pickup_clean_gallons: 2,
        pickup_waste_gallons: 10
      }
    end
  end
end
