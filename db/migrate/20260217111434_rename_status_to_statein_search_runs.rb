class RenameStatusToStateinSearchRuns < ActiveRecord::Migration[8.1]
  def change
    rename_column :search_runs, :status, :state
  end
end
