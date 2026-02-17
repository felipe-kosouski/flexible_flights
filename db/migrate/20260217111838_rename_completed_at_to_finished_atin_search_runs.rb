class RenameCompletedAtToFinishedAtinSearchRuns < ActiveRecord::Migration[8.1]
  def change
    rename_column :search_runs, :completed_at, :finished_at
  end
end
