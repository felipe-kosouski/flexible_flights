class AddCurrencyToSearchIntents < ActiveRecord::Migration[8.1]
  def change
    add_column :search_intents, :currency, :string, null: false, default: "USD"
  end
end
