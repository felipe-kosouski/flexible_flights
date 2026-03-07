# frozen_string_literal: true

class FixSearchIntents < ActiveRecord::Migration[8.1]
  def up
    remove_index :search_intents, name: "index_search_intents_on_origin_airport_and_destination_airport"

    change_column_null :search_intents, :origin_airport, false
    change_column_null :search_intents, :destination_airport, false
    change_column_null :search_intents, :earliest_departure, false
    change_column_null :search_intents, :latest_return, false
    change_column_null :search_intents, :min_stay_days, false
    change_column_null :search_intents, :max_stay_days, false
  end

  def down
    change_column_null :search_intents, :max_stay_days, true
    change_column_null :search_intents, :min_stay_days, true
    change_column_null :search_intents, :latest_return, true
    change_column_null :search_intents, :earliest_departure, true
    change_column_null :search_intents, :destination_airport, true
    change_column_null :search_intents, :origin_airport, true

    add_index :search_intents, [ :origin_airport, :destination_airport ], unique: true
  end
end
