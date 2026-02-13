class CreateSearchIntents < ActiveRecord::Migration[8.1]
  def change
    create_table :search_intents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :origin_airport
      t.string :destination_airport
      t.date :earliest_departure
      t.date :latest_return
      t.integer :min_stay_days
      t.integer :max_stay_days
      t.integer :luggage_requirement
      t.integer :max_stops

      t.timestamps
    end
    add_index :search_intents, [ :origin_airport, :destination_airport ], unique: true
  end
end
