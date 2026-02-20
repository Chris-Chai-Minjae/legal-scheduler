# frozen_string_literal: true

require "test_helper"

module Blog
  class DocumentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      sign_in_as(@user)

      @document = blog_documents(:one)
    end

    # Index 액션 테스트
    test "should get index" do
      get blog_documents_url
      assert_response :success
    end

    test "should filter documents by tag" do
      # 다른 태그 문서 생성
      @user.blog_documents.create!(
        filename: "test2.pdf",
        file_type: "pdf",
        file_size: 1024,
        tag: "계약서"
      )

      get blog_documents_url, params: { tag: "판결문" }
      assert_response :success
      assert_includes @response.body, "판결문"
    end

    # Create 액션 테스트 (파일 업로드)
    test "should create document with valid file" do
      # PDF 파일 생성
      pdf_file = fixture_file_upload("files/test.pdf", "application/pdf")

      assert_difference("BlogDocument.count") do
        assert_enqueued_with(job: BlogDocumentIngestJob) do
          post blog_documents_url, params: {
            blog_document: {
              file: pdf_file,
              tag: "판결문"
            }
          }
        end
      end

      assert_redirected_to blog_documents_url
      assert_equal "문서가 업로드되었습니다. 처리 중입니다.", flash[:notice]
    end

    test "should create document with turbo_stream" do
      pdf_file = fixture_file_upload("files/test.pdf", "application/pdf")

      assert_difference("BlogDocument.count") do
        post blog_documents_url, params: {
          blog_document: {
            file: pdf_file,
            tag: "판결문"
          }
        }, as: :turbo_stream
      end

      assert_response :success
      assert_match "turbo-stream", @response.body
    end

    test "should not create document without file" do
      assert_no_difference("BlogDocument.count") do
        post blog_documents_url, params: {
          blog_document: {
            tag: "판결문"
          }
        }
      end

      assert_redirected_to blog_documents_url
      assert_match /업로드에 실패/, flash[:alert]
    end

    test "should not create document with invalid file type" do
      # TXT 파일 (허용되지 않음)
      txt_file = fixture_file_upload("files/test.txt", "text/plain")

      assert_no_difference("BlogDocument.count") do
        post blog_documents_url, params: {
          blog_document: {
            file: txt_file
          }
        }
      end

      assert_redirected_to blog_documents_url
      assert_match /업로드에 실패/, flash[:alert]
    end

    test "should not create document with oversized file" do
      # 50MB 초과 파일 시뮬레이션
      large_file = fixture_file_upload("files/test.pdf", "application/pdf")

      # ActiveStorage Blob 크기 스텁
      BlogDocument.any_instance.stub(:validate_file_size, -> { errors.add(:file, "크기는 50MB 이하여야 합니다.") }) do
        assert_no_difference("BlogDocument.count") do
          post blog_documents_url, params: {
            blog_document: {
              file: large_file
            }
          }
        end

        assert_redirected_to blog_documents_url
        assert_match /업로드에 실패/, flash[:alert]
      end
    end

    # Destroy 액션 테스트
    test "should destroy document" do
      assert_difference("BlogDocument.count", -1) do
        delete blog_document_url(@document)
      end

      assert_redirected_to blog_documents_url
      assert_equal "문서가 삭제되었습니다.", flash[:notice]
    end

    test "should destroy document with turbo_stream" do
      assert_difference("BlogDocument.count", -1) do
        delete blog_document_url(@document), as: :turbo_stream
      end

      assert_response :success
      assert_match "turbo-stream", @response.body
    end

    test "should not destroy other user's document" do
      other_document = @other_user.blog_documents.create!(
        filename: "other.pdf",
        file_type: "pdf",
        file_size: 1024
      )

      assert_raises(ActiveRecord::RecordNotFound) do
        delete blog_document_url(other_document)
      end
    end

    # 인증 필수 테스트
    test "should require authentication" do
      sign_out
      get blog_documents_url
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
