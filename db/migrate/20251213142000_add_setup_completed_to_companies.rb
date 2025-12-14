class AddSetupCompletedToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :setup_completed, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        Company.reset_column_information
        Company.update_all(setup_completed: true)
      end
    end
  end
end
