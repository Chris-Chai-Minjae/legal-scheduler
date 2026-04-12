class AddImagesToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_posts, :images, :jsonb, default: []
    add_index :blog_posts, :images, using: :gin
  end
end
