class CreateCreditPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_session_id, null: false
      t.string :pack_key, null: false
      t.integer :credits_granted, null: false
      t.string :currency, null: false
      t.integer :amount_cents, null: false
      t.datetime :fulfilled_at, null: false
      t.timestamps
    end

    add_index :credit_purchases, :stripe_session_id, unique: true
  end
end
