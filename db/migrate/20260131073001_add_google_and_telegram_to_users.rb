class AddGoogleAndTelegramToUsers < ActiveRecord::Migration[8.1]
  def change
    # @TASK T0.2 - Add Google OAuth and Telegram fields to users
    # @SPEC docs/planning/04-database-design.md#users-table

    add_column :users, :google_access_token, :text
    add_column :users, :google_refresh_token, :text
    add_column :users, :google_token_expires_at, :datetime
    add_column :users, :telegram_chat_id, :string
    add_column :users, :telegram_bot_token, :string

    # Add indexes for telegram lookups
    add_index :users, :telegram_chat_id, unique: true, where: "telegram_chat_id IS NOT NULL"
  end
end
