class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.date :due_on, null: false
      t.string :status, null: false, default: "todo"
      t.text :notes
      t.datetime :completed_at

      t.timestamps
    end

    add_index :tasks, [ :company_id, :due_on ]
    add_index :tasks, [ :company_id, :status ]
  end
end
