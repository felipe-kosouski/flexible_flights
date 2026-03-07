# frozen_string_literal: true

class FixAnalysisSnapshots < ActiveRecord::Migration[8.1]
  def up
    # Enforce has_one :analysis_snapshot at DB level
    remove_index :analysis_snapshots, name: "index_analysis_snapshots_on_search_run_id"
    add_index :analysis_snapshots, :search_run_id, unique: true

    # Align column name with domain vocabulary (preserves data)
    rename_column :analysis_snapshots, :sample_size, :sample_count

    # Replace float volatility_index (always NULL, wrong type) with integer enum
    remove_column :analysis_snapshots, :volatility_index
    add_column :analysis_snapshots, :volatility, :integer

    # Enforce not null on enum columns
    change_column_null :analysis_snapshots, :confidence_level, false
  end

  def down
    change_column_null :analysis_snapshots, :confidence_level, true

    remove_column :analysis_snapshots, :volatility
    add_column :analysis_snapshots, :volatility_index, :float

    rename_column :analysis_snapshots, :sample_count, :sample_size

    remove_index :analysis_snapshots, :search_run_id
    add_index :analysis_snapshots, :search_run_id
  end
end
