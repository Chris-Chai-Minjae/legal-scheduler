class AddTelegramBotTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :telegram_bot_token, :string
  end
end
