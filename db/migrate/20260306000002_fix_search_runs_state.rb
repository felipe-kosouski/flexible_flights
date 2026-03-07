# frozen_string_literal: true

class FixSearchRunsState < ActiveRecord::Migration[8.1]
  def up
    change_column_default :search_runs, :state, 0
    change_column_null :search_runs, :state, false, 0
  end

  def down
    change_column_null :search_runs, :state, true
    change_column_default :search_runs, :state, nil
  end
end
