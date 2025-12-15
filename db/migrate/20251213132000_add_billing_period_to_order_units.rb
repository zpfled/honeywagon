class AddBillingPeriodToOrderUnits < ActiveRecord::Migration[7.0]
  def up
    add_column :order_units, :billing_period, :string

    execute(<<~SQL.squish)
      WITH ordered_units AS (
        SELECT
          ou.id,
          ou.order_id,
          u.unit_type_id,
          ROW_NUMBER() OVER (
            PARTITION BY ou.order_id, u.unit_type_id
            ORDER BY ou.created_at, ou.id
          ) AS slot_index
        FROM order_units ou
        JOIN units u ON u.id = ou.unit_id
      ),
      expanded_line_items AS (
        SELECT
          oli.order_id,
          oli.unit_type_id,
          oli.billing_period,
          generate_series(1, oli.quantity) AS slot_index
        FROM rental_line_items oli
      )
      UPDATE order_units ou
         SET billing_period = eli.billing_period
        FROM ordered_units ou_ord
        JOIN expanded_line_items eli
          ON eli.order_id = ou_ord.order_id
         AND eli.unit_type_id = ou_ord.unit_type_id
         AND eli.slot_index = ou_ord.slot_index
       WHERE ou.id = ou_ord.id
         AND ou.billing_period IS NULL
    SQL

    execute(<<~SQL.squish)
      UPDATE order_units
         SET billing_period = 'monthly'
       WHERE billing_period IS NULL
    SQL

    change_column_null :order_units, :billing_period, false
    add_index :order_units, :billing_period
  end

  def down
    remove_index :order_units, :billing_period
    remove_column :order_units, :billing_period
  end
end
