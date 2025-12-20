class CreateDumpSitesAndSupportDumpEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :dump_sites, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :location, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.timestamps
    end

    add_reference :service_events, :dump_site, type: :uuid, foreign_key: true
    change_column_null :service_events, :order_id, true
  end
end
