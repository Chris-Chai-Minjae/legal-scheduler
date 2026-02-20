class CreateBlogPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.text :prompt, null: false
      t.integer :tone, default: 0, null: false        # enum: professional(0), easy(1), storytelling(2)
      t.integer :length_setting, default: 1, null: false  # enum: short(0), medium(1), long(2)
      t.integer :status, default: 0, null: false       # enum: draft(0), generating(1), completed(2), published(3)
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :blog_posts, [:user_id, :created_at]
    add_index :blog_posts, :status
  end
end
