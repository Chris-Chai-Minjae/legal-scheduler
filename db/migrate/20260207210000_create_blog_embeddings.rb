class CreateBlogEmbeddings < ActiveRecord::Migration[8.0]
  def up
    create_table :blog_embeddings do |t|
      t.references :blog_document, null: false, foreign_key: { on_delete: :cascade }
      t.integer :chunk_index, null: false
      t.text :chunk_text, null: false
      t.jsonb :metadata, default: {}

      t.timestamp :created_at, default: -> { 'NOW()' }
    end

    # vector 컬럼: pgvector 확장이 있을 때만 추가
    if vector_extension_available?
      execute "ALTER TABLE blog_embeddings ADD COLUMN embedding vector(1024);"
      execute <<-SQL
        CREATE INDEX idx_blog_embeddings_vector
        ON blog_embeddings USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100);
      SQL
    else
      Rails.logger.warn("[Migration] pgvector not available - embedding column skipped. Install pgvector later.")
    end

    add_index :blog_embeddings, [:blog_document_id, :chunk_index],
              name: 'idx_blog_embeddings_document'

    execute <<-SQL
      CREATE INDEX idx_blog_embeddings_metadata
      ON blog_embeddings USING gin (metadata);
    SQL
  end

  def down
    drop_table :blog_embeddings
  end

  private

  def vector_extension_available?
    execute("CREATE EXTENSION IF NOT EXISTS vector")
    true
  rescue ActiveRecord::StatementInvalid
    false
  end
end
