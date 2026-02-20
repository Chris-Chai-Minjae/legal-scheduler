# @TASK P1-R3-T1 - Blog::ChatsController test
# @SPEC SSE 프록시 패턴, ActionController::Live

require "test_helper"

class Blog::ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @post = blog_posts(:one)
    sign_in_as(@user)
  end

  # Scenario 1: 사용자 메시지 저장
  test "should create user chat message" do
    # GIVEN: 사용자가 블로그 포스트에 대화를 시작할 때
    assert_difference("@post.blog_chats.count", 2) do # user + assistant
      # WHEN: 메시지를 전송하면
      post blog_post_chats_path(@post), params: {
        blog_chat: { content: "이 글을 더 간결하게 만들어주세요" }
      }
    end

    # THEN: 사용자 메시지가 저장된다
    user_chat = @post.blog_chats.where(role: "user").last
    assert_equal "이 글을 더 간결하게 만들어주세요", user_chat.content
    assert_equal @user, user_chat.user

    # AND: AI 응답도 저장된다
    assistant_chat = @post.blog_chats.where(role: "assistant").last
    assert_equal "assistant", assistant_chat.role
    assert_not_nil assistant_chat.content
  end

  # Scenario 2: Turbo Stream 응답 확인
  test "should respond with turbo_stream format" do
    # GIVEN: Turbo Stream 요청 헤더가 있을 때
    # WHEN: 메시지를 전송하면
    post blog_post_chats_path(@post), params: {
      blog_chat: { content: "테스트 메시지" }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    # THEN: Turbo Stream으로 응답한다
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  # Scenario 3: 인증 필요 확인
  test "should require authentication" do
    # GIVEN: 로그아웃 상태에서
    sign_out

    # WHEN: 메시지를 전송하려고 하면
    post blog_post_chats_path(@post), params: {
      blog_chat: { content: "테스트" }
    }

    # THEN: 로그인 페이지로 리다이렉트된다
    assert_redirected_to new_session_path
  end

  # Scenario 4: 다른 사용자의 post 접근 차단
  test "should not access other user's post" do
    # GIVEN: 다른 사용자의 포스트가 있을 때
    other_post = blog_posts(:draft_post)
    other_post.update!(user: @other_user)

    # WHEN: 해당 포스트에 메시지를 전송하려고 하면
    assert_raises(ActiveRecord::RecordNotFound) do
      post blog_post_chats_path(other_post), params: {
        blog_chat: { content: "접근 불가" }
      }
    end
  end

  # Scenario 5: 빈 메시지 거부
  test "should not create chat with empty content" do
    # GIVEN: 빈 메시지를 전송하면
    assert_raises(ActiveRecord::RecordInvalid) do
      post blog_post_chats_path(@post), params: {
        blog_chat: { content: "" }
      }
    end
  end

  # Scenario 6: 대화 히스토리 컨텍스트 확인
  test "should include chat history in context" do
    # GIVEN: 기존 대화 내역이 있을 때
    @post.blog_chats.create!(user: @user, role: "user", content: "첫 번째 질문")
    @post.blog_chats.create!(user: @user, role: "assistant", content: "첫 번째 답변")

    # WHEN: 새 메시지를 전송하면
    post blog_post_chats_path(@post), params: {
      blog_chat: { content: "두 번째 질문" }
    }

    # THEN: 대화 히스토리가 유지된다
    assert_equal 4, @post.blog_chats.count # 기존 2개 + 새 user + 새 assistant
    chats = @post.blog_chats.chronological
    assert_equal "첫 번째 질문", chats.first.content
    assert_equal "두 번째 질문", chats.third.content
  end

  private

  def sign_in_as(user)
    post session_url, params: {
      email_address: user.email_address,
      password: "password"
    }
  end

  def sign_out
    delete session_url
  end
end
