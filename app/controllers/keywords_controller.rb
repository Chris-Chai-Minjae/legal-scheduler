# @TASK T3.1 - Keywords management controller
# @SPEC REQ-SET-01: Keyword CRUD operations

class KeywordsController < ApplicationController
  before_action :set_keyword, only: [:destroy, :toggle]

  # GET /keywords
  def index
    @keywords = Current.user.keywords.order(created_at: :asc)
    @keyword = Keyword.new
  end

  # POST /keywords
  def create
    @keyword = Current.user.keywords.build(keyword_params)

    if @keyword.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("keywords-list", partial: "keywords/keyword", locals: { keyword: @keyword }),
            turbo_stream.replace("keyword-form", partial: "keywords/form", locals: { keyword: Keyword.new })
          ]
        end
        format.html { redirect_to keywords_path, notice: "키워드가 추가되었습니다." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("keyword-form", partial: "keywords/form", locals: { keyword: @keyword })
        end
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /keywords/:id
  def destroy
    @keyword.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("keyword_#{@keyword.id}")
      end
      format.html { redirect_to keywords_path, notice: "키워드가 삭제되었습니다." }
    end
  end

  # POST /keywords/:id/toggle
  def toggle
    @keyword.update!(is_active: !@keyword.is_active)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("keyword_#{@keyword.id}", partial: "keywords/keyword", locals: { keyword: @keyword })
      end
      format.html { redirect_to keywords_path }
    end
  end

  private

  def set_keyword
    @keyword = Current.user.keywords.find(params[:id])
  end

  def keyword_params
    params.require(:keyword).permit(:keyword)
  end
end
