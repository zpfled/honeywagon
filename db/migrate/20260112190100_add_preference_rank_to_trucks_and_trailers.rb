class AddPreferenceRankToTrucksAndTrailers < ActiveRecord::Migration[8.1]
  def change
    add_column :trucks, :preference_rank, :integer
    add_column :trailers, :preference_rank, :integer
  end
end
