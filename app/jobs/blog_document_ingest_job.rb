# BlogDocumentIngestJob
# 업로드된 문서를 FastAPI RAG 시스템에 인제스트하는 Job
# Solid Queue로 큐잉됨 (Redis 사용 안 함)
class BlogDocumentIngestJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(document_id)
    document = BlogDocument.find(document_id)

    # 상태를 processing으로 변경
    document.update!(status: :processing)

    # 파일 경로 준비
    file_path = ActiveStorage::Blob.service.path_for(document.file.key)

    # BlogAiService.ingest 호출 (클래스 메서드)
    result = BlogAiService.ingest(
      file_path: file_path,
      file_type: document.file_type,
      user_id: document.user_id,
      tag: document.tag || ""
    )

    # 성공 여부 확인
    unless result[:success]
      raise "FastAPI 인제스트 실패: #{result[:error]}"
    end

    # 성공 시 상태를 ready로, chunk_count/qdrant_ids 업데이트
    document.update!(
      status: :ready,
      chunk_count: result[:chunk_count],
      qdrant_ids: result[:qdrant_ids]&.join(",") # Array를 콤마 구분 문자열로
    )

    Rails.logger.info "[BlogDocumentIngestJob] 문서 #{document.id} 인제스트 완료: #{result[:chunk_count]} chunks"
  rescue => e
    Rails.logger.error "[BlogDocumentIngestJob] 문서 #{document_id} 인제스트 실패: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # 실패 시 상태를 failed로 변경
    document = BlogDocument.find(document_id)
    document.update!(status: :failed)

    raise e
  end
end
