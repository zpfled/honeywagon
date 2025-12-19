class AddCompanyToRatePlans < ActiveRecord::Migration[8.1]
  def up
    add_reference :rate_plans, :company, foreign_key: true, type: :uuid, null: true

    execute <<~SQL.squish
      UPDATE rate_plans
      SET company_id = unit_types.company_id
      FROM unit_types
      WHERE rate_plans.unit_type_id = unit_types.id
    SQL

    change_column_null :rate_plans, :company_id, false
    change_column_null :rate_plans, :unit_type_id, true
  end

  def down
    change_column_null :rate_plans, :unit_type_id, false
    remove_reference :rate_plans, :company, foreign_key: true
  end
end
