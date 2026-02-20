class Blog::DocumentsController < ApplicationController
  def index
    @documents = Current.user.blog_documents
                          .by_tag(params[:tag])
                          .order(created_at: :desc)
  end

  def create
    @document = Current.user.blog_documents.build(document_params)

    if @document.save
      # Solid Queue로 인제스트 Job 큐잉
      BlogDocumentIngestJob.perform_later(@document.id)

      respond_to do |format|
        format.html { redirect_to blog_documents_path, notice: "문서가 업로드되었습니다. 처리 중입니다." }
        format.turbo_stream {
          flash.now[:notice] = "문서가 업로드되었습니다. 처리 중입니다."
          render turbo_stream: [
            turbo_stream.prepend("documents-list", partial: "blog/documents/document", locals: { document: @document }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        }
      end
    else
      respond_to do |format|
        format.html { redirect_to blog_documents_path, alert: "문서 업로드에 실패했습니다: #{@document.errors.full_messages.join(', ')}" }
        format.turbo_stream {
          flash.now[:alert] = "문서 업로드에 실패했습니다: #{@document.errors.full_messages.join(', ')}"
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
        }
      end
    end
  end

  def destroy
    @document = Current.user.blog_documents.find(params[:id])
    @document.destroy

    respond_to do |format|
      format.html { redirect_to blog_documents_path, notice: "문서가 삭제되었습니다." }
      format.turbo_stream {
        flash.now[:notice] = "문서가 삭제되었습니다."
        render turbo_stream: [
          turbo_stream.remove("document_#{@document.id}"),
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      }
    end
  end

  private

  def document_params
    # ActiveStorage가 자동으로 파일 메타데이터를 설정하므로 file만 필수
    params.require(:blog_document).permit(:file, :tag)
  end
end
