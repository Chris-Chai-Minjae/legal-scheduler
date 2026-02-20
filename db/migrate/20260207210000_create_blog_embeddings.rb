class CreateBlogEmbeddings < ActiveRecord::Migration[8.0]
  # DDL 트랜잭션 비활성화 - extension 생성 실패가 전체 마이그레이션을 롤백하지 않도록
  disable_ddl_transaction!

  def up
    unless table_exists?(:blog_embeddings)
      create_table :blog_embeddings do |t|
        t.references :blog_document, null: false, foreign_key: { on_delete: :cascade }
        t.integer :chunk_index, null: false
        t.text :chunk_text, null: false
        t.jsonb :metadata, default: {}

        t.timestamp :created_at, default: -> { 'NOW()' }
      end
    end

    # vector 컬럼: pgvector 확장이 있을 때만 추가
    if vector_extension_available?
      unless column_exists?(:blog_embeddings, :embedding)
        execute "ALTER TABLE blog_embeddings ADD COLUMN embedding vector(1024);"
      end
      unless index_exists?(:blog_embeddings, name: 'idx_blog_embeddings_vector')
        execute <<-SQL
          CREATE INDEX idx_blog_embeddings_vector
          ON blog_embeddings USING ivfflat (embedding vector_cosine_ops)
          WITH (lists = 100);
        SQL
      end
    else
      Rails.logger.warn("[Migration] pgvector not available - embedding column skipped.")
    end

    unless index_exists?(:blog_embeddings, [:blog_document_id, :chunk_index], name: 'idx_blog_embeddings_document')
      add_index :blog_embeddings, [:blog_document_id, :chunk_index],
                name: 'idx_blog_embeddings_document'
    end

    unless index_exists?(:blog_embeddings, name: 'idx_blog_embeddings_metadata')
      execute <<-SQL
        CREATE INDEX idx_blog_embeddings_metadata
        ON blog_embeddings USING gin (metadata);
      SQL
    end
  end

  def down
    drop_table :blog_embeddings if table_exists?(:blog_embeddings)
  end

  private

  def vector_extension_available?
    result = execute("SELECT 1 FROM pg_available_extensions WHERE name = 'vector'")
    return false if result.count == 0

    execute("CREATE EXTENSION IF NOT EXISTS vector")
    true
  rescue ActiveRecord::StatementInvalid
    false
  end
end
