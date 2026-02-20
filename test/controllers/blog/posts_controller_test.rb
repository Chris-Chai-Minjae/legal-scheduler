# frozen_string_literal: true

require "test_helper"

module Blog
  class PostsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      sign_in_as(@user)

      @post = blog_posts(:one)
      @other_post = blog_posts(:two)
    end

    # Index 액션 테스트
    test "should get index" do
      get blog_posts_url
      assert_response :success
      assert_select "h1", "블로그 글 목록"
    end

    test "should search posts by title" do
      get blog_posts_url, params: { q: @post.title }
      assert_response :success
      assert_includes @response.body, @post.title
    end

    test "should paginate posts" do
      # 15개 글 생성 (PER_PAGE = 10이므로 2페이지 생성)
      15.times do |i|
        @user.blog_posts.create!(
          title: "Test Post #{i}",
          prompt: "Test prompt #{i}",
          tone: :professional,
          length_setting: :medium
        )
      end

      get blog_posts_url, params: { page: 1 }
      assert_response :success

      get blog_posts_url, params: { page: 2 }
      assert_response :success
    end

    # New 액션 테스트
    test "should get new" do
      get blog_write_url
      assert_response :success
      assert_select "form"
    end

    # Create 액션 테스트
    test "should create post" do
      assert_difference("BlogPost.count") do
        post blog_posts_url, params: {
          blog_post: {
            title: "New Blog Post",
            prompt: "Write about Rails 8",
            tone: :professional,
            length_setting: :medium
          }
        }
      end

      assert_redirected_to blog_post_url(BlogPost.last)
      assert_equal "블로그 글이 생성되었습니다.", flash[:notice]
    end

    test "should not create post with invalid params" do
      assert_no_difference("BlogPost.count") do
        post blog_posts_url, params: {
          blog_post: {
            title: "",
            prompt: ""
          }
        }
      end

      assert_response :unprocessable_entity
    end

    test "should create post with turbo_stream" do
      assert_difference("BlogPost.count") do
        post blog_posts_url, params: {
          blog_post: {
            title: "Turbo Stream Post",
            prompt: "Turbo test",
            tone: :professional,
            length_setting: :short
          }
        }, as: :turbo_stream
      end

      assert_response :success
      assert_match "turbo-stream", @response.body
    end

    # Show 액션 테스트
    test "should show post" do
      get blog_post_url(@post)
      assert_response :success
      assert_select "h1", @post.title
    end

    test "should not show other user's post" do
      assert_raises(ActiveRecord::RecordNotFound) do
        get blog_post_url(@other_post)
      end
    end

    # Edit 액션 테스트
    test "should get edit" do
      get edit_blog_post_url(@post)
      assert_response :success
      assert_select "form"
    end

    test "should not edit other user's post" do
      assert_raises(ActiveRecord::RecordNotFound) do
        get edit_blog_post_url(@other_post)
      end
    end

    # Update 액션 테스트
    test "should update post" do
      patch blog_post_url(@post), params: {
        blog_post: {
          title: "Updated Title",
          content: "Updated content"
        }
      }

      assert_redirected_to blog_post_url(@post)
      assert_equal "블로그 글이 수정되었습니다.", flash[:notice]
      @post.reload
      assert_equal "Updated Title", @post.title
    end

    test "should not update post with invalid params" do
      patch blog_post_url(@post), params: {
        blog_post: {
          title: "",
          prompt: ""
        }
      }

      assert_response :unprocessable_entity
    end

    test "should update post with turbo_stream" do
      patch blog_post_url(@post), params: {
        blog_post: {
          title: "Turbo Updated"
        }
      }, as: :turbo_stream

      assert_response :success
      assert_match "turbo-stream", @response.body
    end

    test "should not update other user's post" do
      assert_raises(ActiveRecord::RecordNotFound) do
        patch blog_post_url(@other_post), params: {
          blog_post: { title: "Hacked" }
        }
      end
    end

    # Destroy 액션 테스트
    test "should destroy post" do
      assert_difference("BlogPost.count", -1) do
        delete blog_post_url(@post)
      end

      assert_redirected_to blog_posts_url
      assert_equal "블로그 글이 삭제되었습니다.", flash[:notice]
    end

    test "should destroy post with turbo_stream" do
      assert_difference("BlogPost.count", -1) do
        delete blog_post_url(@post), as: :turbo_stream
      end

      assert_response :success
      assert_match "turbo-stream", @response.body
    end

    test "should not destroy other user's post" do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete blog_post_url(@other_post)
      end
    end

    # Regenerate 액션 테스트 (SSE는 통합 테스트에서 별도 확인)
    test "should regenerate post" do
      # BlogAiService 스텁 처리
      stub_generate = proc do |*args, **kwargs, &block|
        block.call("test chunk") if block
      end

      BlogAiService.stub :generate, stub_generate do
        post regenerate_blog_post_url(@post)
        assert_response :success
      end
    end

    test "should not regenerate other user's post" do
      assert_raises(ActiveRecord::RecordNotFound) do
        post regenerate_blog_post_url(@other_post)
      end
    end

    # 인증 필수 테스트
    test "should require authentication" do
      sign_out
      get blog_posts_url
      assert_redirected_to root_url
    end

    private

    def sign_in_as(user)
      post session_url, params: { email: user.email, password: "password" }
    end

    def sign_out
      delete session_url
    end
  end
end
