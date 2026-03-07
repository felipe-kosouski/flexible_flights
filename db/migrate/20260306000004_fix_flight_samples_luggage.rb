# frozen_string_literal: true

class FixFlightSamplesLuggage < ActiveRecord::Migration[8.1]
  def up
    # Backfill any NULLs before adding constraint (validated in AR but DB allowed NULL)
    execute "UPDATE flight_samples SET luggage_included = false WHERE luggage_included IS NULL"
    change_column_null :flight_samples, :luggage_included, false
  end

  def down
    change_column_null :flight_samples, :luggage_included, true
  end
end
