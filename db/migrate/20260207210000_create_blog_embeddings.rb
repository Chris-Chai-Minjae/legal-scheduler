class CreateBlogEmbeddings < ActiveRecord::Migration[8.0]
  def up
    # pgvector 확장이 이미 설치되어 있다고 가정
    # (LXC 106에서 setup_pgvector.sql 먼저 실행)

    # blog_embeddings 테이블 생성
    create_table :blog_embeddings do |t|
      t.references :blog_document, null: false, foreign_key: { on_delete: :cascade }
      t.integer :chunk_index, null: false          # 청크 순서 (0부터 시작)
      t.text :chunk_text, null: false              # 원본 텍스트
      t.jsonb :metadata, default: {}               # 추가 메타데이터

      t.timestamp :created_at, default: -> { 'NOW()' }
    end

    # embedding 컬럼 추가 (vector 타입은 execute로 직접 추가)
    execute <<-SQL
      ALTER TABLE blog_embeddings
      ADD COLUMN embedding vector(1024);
    SQL

    # 벡터 유사도 검색 인덱스 (IVFFlat, Cosine Distance)
    execute <<-SQL
      CREATE INDEX idx_blog_embeddings_vector
      ON blog_embeddings USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100);
    SQL

    # 문서별 조회 인덱스
    add_index :blog_embeddings, [:blog_document_id, :chunk_index],
              name: 'idx_blog_embeddings_document'

    # 메타데이터 검색 인덱스 (GIN)
    execute <<-SQL
      CREATE INDEX idx_blog_embeddings_metadata
      ON blog_embeddings USING gin (metadata);
    SQL
  end

  def down
    drop_table :blog_embeddings
  end
end
