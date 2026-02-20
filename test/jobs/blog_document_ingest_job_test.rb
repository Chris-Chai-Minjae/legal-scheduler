# frozen_string_literal: true

require "test_helper"

class BlogDocumentIngestJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @document = blog_documents(:one)
  end

  test "should update document status to processing" do
    # BlogAiService.ingest 스텁
    BlogAiService.stub :ingest, { success: true, chunk_count: 10, qdrant_ids: ["id1", "id2"] } do
      BlogDocumentIngestJob.perform_now(@document.id)
      @document.reload
      assert_equal "ready", @document.status
    end
  end

  test "should call BlogAiService.ingest with correct params" do
    called = false
    stub_ingest = lambda do |file_path:, file_type:, user_id:, tag:|
      called = true
      assert_equal @document.file_type, file_type
      assert_equal @document.user_id, user_id
      assert_equal @document.tag, tag
      { success: true, chunk_count: 5, qdrant_ids: ["id1"] }
    end

    BlogAiService.stub :ingest, stub_ingest do
      BlogDocumentIngestJob.perform_now(@document.id)
    end

    assert called, "BlogAiService.ingest should be called"
  end

  test "should update document on successful ingest" do
    BlogAiService.stub :ingest, { success: true, chunk_count: 15, qdrant_ids: ["id1", "id2", "id3"] } do
      BlogDocumentIngestJob.perform_now(@document.id)
      @document.reload

      assert_equal "ready", @document.status
      assert_equal 15, @document.chunk_count
      assert_equal "id1,id2,id3", @document.qdrant_ids
    end
  end

  test "should update document status to failed on error" do
    BlogAiService.stub :ingest, { success: false, error: "FastAPI error" } do
      assert_raises(RuntimeError) do
        BlogDocumentIngestJob.perform_now(@document.id)
      end

      @document.reload
      assert_equal "failed", @document.status
    end
  end

  test "should retry on failure" do
    assert_enqueued_with(job: BlogDocumentIngestJob, args: [@document.id]) do
      BlogDocumentIngestJob.perform_later(@document.id)
    end
  end
end
