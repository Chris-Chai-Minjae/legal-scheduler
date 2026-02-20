class CreateBlogChats < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_chats do |t|
      t.references :blog_post, foreign_key: true  # nullable
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false          # user, assistant
      t.text :content, null: false

      t.timestamps
    end

    add_index :blog_chats, [:blog_post_id, :created_at]
  end
end
