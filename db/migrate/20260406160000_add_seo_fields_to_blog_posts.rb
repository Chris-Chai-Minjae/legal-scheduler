class AddSeoFieldsToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_posts, :description, :string, limit: 160, comment: "메타 디스크립션"
    add_column :blog_posts, :slug, :string, comment: "URL 슬러그"
    add_column :blog_posts, :seo_score, :integer, comment: "SEO 평가 총점 (0~100)"
    add_column :blog_posts, :seo_details, :jsonb, comment: "SEO 분석 세부 결과"
    add_column :blog_posts, :seo_analyzed_at, :datetime, comment: "마지막 SEO 분석 시간"
    add_column :blog_posts, :target_keywords, :string, array: true, default: [], comment: "타겟 키워드 목록"

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :seo_score
  end
end
