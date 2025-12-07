class AddNextSerialToUnitTypes < ActiveRecord::Migration[7.1]
  def up
    add_column :unit_types, :next_serial, :integer, null: false, default: 1

    # Backfill based on existing units, if any
    GenericUnitType.reset_column_information

    GenericUnitType.find_each do |unit_type|
      prefix = unit_type.prefix
      next unless prefix.present?

      last_serial = GenericUnitUnit.where(unit_type_id: unit_type.id)
                        .where("serial LIKE ?", "#{prefix}-%")
                        .pluck(:serial)
                        .map { |s| s.split("-").last.to_i }
                        .max

      next_number = (last_serial || 0) + 1
      unit_type.update_columns(next_serial: next_number)
    end
  end

  def down
    remove_column :unit_types, :next_serial
  end

  class GenericUnitType < ApplicationRecord
    self.table_name = "unit_types"
  end

  class GenericUnit < ApplicationRecord
    self.table_name = "units"
  end
end
