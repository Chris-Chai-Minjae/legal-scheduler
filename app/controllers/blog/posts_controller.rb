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

    # Save image options to metadata (jsonb) — regenerate에서 사용
    image_preset = (params.dig(:blog_post, :image_preset).presence || "auto").to_s
    image_count_raw = params.dig(:blog_post, :image_count).to_i
    image_count = image_preset == "none" ? 0 : image_count_raw.clamp(1, 4)
    image_count = 2 if image_count.zero? && image_preset != "none"
    @post.metadata ||= {}
    @post.metadata["image_preset"] = image_preset
    @post.metadata["image_count"] = image_count
    image_style = (params.dig(:blog_post, :image_style).presence || "auto").to_s
    @post.metadata["image_style"] = image_style

    # 제목이 비어있으면 임시 placeholder.
    # 실제 제목은 본문 스트리밍(regenerate) 중 첫 줄 "제목: ..." 라인에서 자동 추출됨.
    # placeholder 는 "생성 중..." 으로 명확히 표시 (SEO 키워드 오판 방지 — 이전 "AI 생성 제목:" 접두어 제거)
    if @post.title.blank?
      @post.title = "생성 중..."
    end

    # 초기 저장 상태: 본문은 placeholder, status=generating → show 페이지에서 auto-stream
    @post.content = "AI가 콘텐츠를 생성하는 중입니다..." if @post.content.blank?
    @post.status = :generating

    respond_to do |format|
      if @post.save
        format.json {
          render json: {
            id: @post.id,
            title: @post.title,
            status: @post.status,
            redirect_url: blog_post_path(@post)
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
    # BlogAiService를 통한 재생성 요청 (생성 중 상태로 변경)
    @post.update(status: :generating)

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"

    # metadata에 저장된 이미지 옵션 읽기
    image_preset = @post.metadata&.dig("image_preset") || "auto"
    image_count = @post.metadata&.dig("image_count")&.to_i || 2
    image_style = @post.metadata&.dig("image_style") || "auto"
    include_images = image_preset != "none" && image_count > 0

    # 본문 전체를 DB에 저장하기 위해 스트리밍 중 누적
    full_text = +""
    leftover = +""

    process_line = lambda do |line|
      return unless line.start_with?("data:")
      json_str = line.sub(/\Adata:\s*/, "").strip
      return if json_str.empty?
      begin
        parsed = JSON.parse(json_str)
        case parsed["type"]
        when "title"
          new_title = parsed["text"].to_s.strip
          if new_title.length.between?(3, 100)
            @post.update_columns(title: new_title, updated_at: Time.current)
          end
        when "description"
          new_desc = parsed["text"].to_s.strip
          if new_desc.length.between?(10, 160)
            @post.update_columns(description: new_desc, updated_at: Time.current)
          end
        when "text"
          unless parsed["done"]
            full_text << parsed["text"].to_s
          end
        when "image"
          if parsed["url"].present?
            @post.add_image(url: parsed["url"], alt: parsed["alt"])
          end
        end
      rescue JSON::ParserError
        # 잘못된 JSON — 무시
      end
    end

    begin
      BlogAiService.generate(
        prompt: @post.prompt,
        tone: @post.tone,
        length: @post.length_setting,
        document_ids: [],
        include_images: include_images,
        image_count: include_images ? image_count : 0,
        image_preset: image_preset == "none" ? "auto" : image_preset,
        image_style: image_style,
        post_id: @post.id
      ) do |chunk|
        # blog-ai(FastAPI sse_starlette)는 이미 "data: {...}\r\n\r\n" 형식으로 보냄
        # → 이중 wrapping 금지, 그대로 passthrough
        response.stream.write(chunk)

        # CRLF/LF 정규화 후 line 단위로 누적 파싱.
        # 마지막 줄은 청크 경계에서 잘릴 수 있으므로 leftover 로 이월.
        normalized = (leftover + chunk.to_s).gsub("\r\n", "\n")
        lines = normalized.split("\n", -1)
        leftover = lines.pop.to_s  # 마지막(미완성 가능) 줄
        lines.each { |l| process_line.call(l) }
      end

      # 마지막 leftover 가 완전한 data: 줄이면 처리
      process_line.call(leftover) if leftover.start_with?("data:")

      response.stream.write("event: done\ndata: {}\n\n")

      # 스트리밍 종료 — DB에 본문 저장 (reload 후에도 보이도록)
      if full_text.strip.length >= 10
        @post.update(content: full_text, status: :completed)
      else
        @post.update(status: :completed)
      end
    rescue ActionController::Live::ClientDisconnected
      Rails.logger.warn("Client disconnected during regenerate (post #{@post.id})")
      # 클라이언트 끊겼어도 받은 만큼 저장
      if full_text.strip.length >= 10
        @post.update(content: full_text, status: :completed)
      else
        @post.update(status: :draft)
      end
    rescue StandardError => e
      Rails.logger.error("Regenerate failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      begin
        response.stream.write("event: error\ndata: {\"error\": \"#{e.message}\"}\n\n")
      rescue StandardError
        # stream already closed
      end
      if full_text.strip.length >= 10
        @post.update(content: full_text, status: :completed)
      else
        @post.update(status: :draft)
      end
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
