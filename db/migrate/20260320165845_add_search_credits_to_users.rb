class AddSearchCreditsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :search_credits, :integer, default: 1, null: false
    execute "ALTER TABLE users ADD CONSTRAINT search_credits_non_negative CHECK (search_credits >= 0)"
  end
end
