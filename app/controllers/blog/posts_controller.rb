class Blog::PostsController < ApplicationController
  include ActionController::Live # SSE 프록시를 위한 모듈
  layout "dashboard"
  before_action :set_post, only: [:show, :edit, :update, :destroy, :regenerate]

  # 페이지당 항목 수
  PER_PAGE = 10

  def index
    # 검색어 처리
    query = Current.user.blog_posts.recent

    if params[:q].present?
      search_term = "%#{params[:q]}%"
      query = query.where("title LIKE ? OR content LIKE ?", search_term, search_term)
    end

    # 페이지네이션 (수동 구현)
    @total_count = query.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil

    @page = (params[:page] || 1).to_i
    @page = 1 if @page < 1
    @page = @total_pages if @total_pages > 0 && @page > @total_pages

    @posts = query.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def new
    @post = BlogPost.new
  end

  def create
    @post = Current.user.blog_posts.build(post_params)

    # Auto-generate title if empty
    if @post.title.blank?
      @post.title = "AI 생성 제목: #{@post.prompt.truncate(30)}"
    end

    # Set default content for initial save
    if @post.content.blank?
      @post.content = "AI가 콘텐츠를 생성하는 중입니다..."
      @post.status = :generating
    end

    respond_to do |format|
      if @post.save
        format.json {
          render json: {
            id: @post.id,
            title: @post.title,
            content: @post.content,
            status: @post.status
          }, status: :created
        }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("posts", partial: "blog/posts/post_card", locals: { post: @post })
        end
        format.html { redirect_to blog_post_path(@post), notice: "블로그 글이 생성되었습니다." }
      else
        format.json {
          render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
        }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("post_form", partial: "blog/posts/form", locals: { post: @post })
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
    @chats = @post.blog_chats.chronological
  end

  def edit
  end

  def update
    respond_to do |format|
      if @post.update(post_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("post_#{@post.id}", partial: "blog/posts/post_card", locals: { post: @post })
        end
        format.json { render json: { success: true, post: @post }, status: :ok }
        format.html { redirect_to blog_post_path(@post), notice: "블로그 글이 수정되었습니다." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("post_form", partial: "blog/posts/form", locals: { post: @post })
        end
        format.json { render json: { success: false, errors: @post.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @post.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("post_#{@post.id}")
      end
      format.html { redirect_to blog_posts_path, notice: "블로그 글이 삭제되었습니다." }
    end
  end

  def regenerate
    # BlogAiService를 통한 재생성 요청
    # 상태를 generating으로 변경
    @post.update(status: :generating)

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"

    begin
      # FastAPI SSE 프록시
      BlogAiService.generate(
        prompt: @post.prompt,
        tone: @post.tone,
        length: @post.length_setting,
        document_ids: []
      ) do |chunk|
        # SSE 형식으로 클라이언트에 전송
        response.stream.write("data: #{chunk}\n\n")
      end

      # 완료 이벤트
      response.stream.write("event: done\ndata: {}\n\n")
      @post.update(status: :completed)
    rescue StandardError => e
      Rails.logger.error("Regenerate failed: #{e.message}")
      response.stream.write("event: error\ndata: {\"error\": \"#{e.message}\"}\n\n")
      @post.update(status: :draft)
    ensure
      response.stream.close
    end
  end

  private

  def set_post
    @post = Current.user.blog_posts.find(params[:id])
  end

  def post_params
    params.require(:blog_post).permit(:title, :prompt, :tone, :length_setting, :content)
  end
end
