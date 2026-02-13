class CreateFlightSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :flight_samples do |t|
      t.references :search_run, null: false, foreign_key: true
      t.string :provider
      t.integer :price_cents
      t.string :currency
      t.integer :air_time_minutes
      t.integer :layover_time_minutes
      t.integer :stops
      t.jsonb :airlines
      t.boolean :luggage_included
      t.datetime :departure_datetime
      t.datetime :return_datetime

      t.timestamps
    end
    add_index :flight_samples, :price_cents
  end
end
