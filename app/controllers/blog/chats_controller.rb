class Blog::ChatsController < ApplicationController
  include ActionController::Live

  before_action :set_post

  def create
    # 1. 사용자 메시지 저장
    user_chat = @post.blog_chats.create!(
      user: Current.user,
      role: "user",
      content: chat_params[:content]
    )

    # 2. SSE 요청 여부 확인
    if request.headers["Accept"]&.include?("text/event-stream")
      stream_ai_response(user_chat)
    else
      # 비-SSE 폴백: Turbo Stream 응답
      create_ai_response_sync(user_chat)
    end
  end

  private

  def set_post
    @post = Current.user.blog_posts.find(params[:post_id])
  end

  def chat_params
    params.require(:blog_chat).permit(:content)
  end

  # SSE 스트리밍 응답
  def stream_ai_response(user_chat)
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no" # nginx 버퍼링 비활성화

    # 대화 히스토리 구성 (최근 20개까지)
    history = @post.blog_chats.chronological.limit(20).map do |c|
      { role: c.role, content: c.content }
    end

    ai_response = ""

    begin
      # BlogAiService가 있으면 사용, 없으면 스텁
      if defined?(BlogAiService)
        BlogAiService.chat(
          message: user_chat.content,
          context: @post.content,
          history: history
        ) do |chunk|
          ai_response += chunk
          response.stream.write("data: #{chunk.to_json}\n\n")
        end
      else
        # 스텁: 더미 응답 스트리밍
        dummy_response = "네, 도움이 필요하신가요? (BlogAiService 스텁 응답)"
        dummy_response.chars.each_slice(5) do |chars|
          chunk = chars.join
          ai_response += chunk
          response.stream.write("data: #{chunk.to_json}\n\n")
          sleep 0.05 # 스트리밍 시뮬레이션
        end
      end

      # AI 응답 완료 시그널
      response.stream.write("data: [DONE]\n\n")

      # AI 응답 저장
      @post.blog_chats.create!(
        user: Current.user,
        role: "assistant",
        content: ai_response
      )
    rescue IOError
      # 클라이언트 연결 끊김
      Rails.logger.info "Client disconnected during SSE streaming"
    ensure
      response.stream.close
    end
  end

  # 비-SSE 폴백: 동기 응답
  def create_ai_response_sync(user_chat)
    # 대화 히스토리 구성
    history = @post.blog_chats.chronological.limit(20).map do |c|
      { role: c.role, content: c.content }
    end

    ai_response = ""

    # BlogAiService가 있으면 사용, 없으면 스텁
    if defined?(BlogAiService)
      BlogAiService.chat(
        message: user_chat.content,
        context: @post.content,
        history: history
      ) do |chunk|
        ai_response += chunk
      end
    else
      # 스텁: 더미 응답
      ai_response = "네, 도움이 필요하신가요? (BlogAiService 스텁 응답)"
    end

    # AI 응답 저장
    @assistant_chat = @post.blog_chats.create!(
      user: Current.user,
      role: "assistant",
      content: ai_response
    )

    # Turbo Stream 뷰를 위한 인스턴스 변수 (user_chat을 @chat으로 설정)
    @chat = user_chat

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to blog_post_path(@post) }
    end
  end
end
