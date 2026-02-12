class CreateSearchRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :search_runs do |t|
      t.references :search_intent, null: false, foreign_key: true
      t.integer :status
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :data_fresh_until

      t.timestamps
    end
  end
end
