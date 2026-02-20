class CreateBlogDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_documents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :file_type, null: false     # pdf, hwp, docx
      t.integer :file_size, null: false
      t.string :tag                         # 판결문, 사례요약, 준비서면
      t.integer :chunk_count, default: 0
      t.jsonb :qdrant_ids, default: []
      t.integer :status, default: 0, null: false  # enum: pending(0), processing(1), ready(2), failed(3)

      t.timestamps
    end

    add_index :blog_documents, [:user_id, :created_at]
    add_index :blog_documents, :status
    add_index :blog_documents, :tag
  end
end
