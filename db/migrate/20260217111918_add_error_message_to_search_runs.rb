class AddErrorMessageToSearchRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :search_runs, :error_message, :text
  end
end
