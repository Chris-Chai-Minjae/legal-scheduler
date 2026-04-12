class Blog::SeoController < ApplicationController
  layout "dashboard"
  before_action :set_post

  def analyze
    result = SeoAnalysisService.analyze(@post)

    respond_to do |format|
      if result
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("seo-panel",
            partial: "blog/posts/seo_panel",
            locals: { post: @post.reload })
        end
        format.json { render json: result }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("seo-panel",
            partial: "blog/posts/seo_panel_error")
        end
        format.json { render json: { error: "분석 실패" }, status: :service_unavailable }
      end
    end
  end

  def optimize
    item_id = params[:item]
    result = SeoAnalysisService.optimize(@post, item_id)

    if result
      render json: result
    else
      render json: { error: "최적화 제안 생성 실패" }, status: :service_unavailable
    end
  end

  def apply
    item_id = params[:item_id]
    field_name = params[:field_name]
    new_value = params[:new_value]

    permitted_fields = %w[title description content slug]
    unless permitted_fields.include?(field_name)
      return render json: { error: "허용되지 않는 필드" }, status: :unprocessable_entity
    end

    # SEO 제안값 길이 검증 (LLM이 전체 본문을 반환해 title에 저장되는 것 방지)
    max_lengths = { "title" => 100, "description" => 200, "slug" => 80, "content" => 10000 }
    max_len = max_lengths[field_name] || 500
    if new_value.to_s.length > max_len
      return render json: { error: "#{field_name} 값이 너무 깁니다 (최대 #{max_len}자)" }, status: :unprocessable_entity
    end

    if @post.update(field_name => new_value)
      # 재분석
      SeoAnalysisService.analyze(@post)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("seo-panel",
            partial: "blog/posts/seo_panel",
            locals: { post: @post.reload })
        end
        format.json { render json: { success: true, post: @post.reload.as_json(only: [:id, :title, :description, :slug, :seo_score]) } }
      end
    else
      render json: { error: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Current.user.blog_posts.find(params[:post_id])
  end
end
