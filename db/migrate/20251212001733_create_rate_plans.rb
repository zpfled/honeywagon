class CreateRatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :rate_plans, id: :uuid do |t|
      t.references :unit_type, null: false, foreign_key: true, type: :uuid
      t.string :service_schedule
      t.string :billing_period
      t.integer :price_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.date :effective_on
      t.date :expires_on

      t.timestamps
    end

    add_index :rate_plans, [ :unit_type_id, :service_schedule, :billing_period ], unique: true
  end
end
