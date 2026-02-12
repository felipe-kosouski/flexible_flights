class CreateAnalysisSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_snapshots do |t|
      t.references :search_run, null: false, foreign_key: true
      t.integer :route_median_duration_minutes
      t.integer :price_p25_cents
      t.integer :price_p50_cents
      t.integer :price_p75_cents
      t.integer :sample_size
      t.float :volatility_index
      t.integer :confidence_level

      t.timestamps
    end
    add_index :search_run_id
  end
end
