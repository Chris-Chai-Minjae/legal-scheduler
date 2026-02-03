# @TASK T3.1 & T9.2 - Keywords management controller
# @SPEC REQ-SET-01: Keyword CRUD operations

class KeywordsController < ApplicationController
  before_action :resume_session
  before_action :set_keyword, only: [:destroy, :toggle]
  layout "dashboard"

  # GET /keywords
  def index
    @keywords = Current.user.keywords.order(created_at: :asc)
    @keyword = Keyword.new
  end

  # POST /keywords
  def create
    # Handle default keywords addition
    if params[:add_defaults]
      add_default_keywords
      redirect_to keywords_path, notice: "기본 키워드가 추가되었습니다."
      return
    end

    # Support both 'name' and 'keyword' params for UI compatibility
    keyword_value = params.dig(:keyword, :name) || params.dig(:keyword, :keyword) || params[:name]

    @keyword = Current.user.keywords.build(keyword: keyword_value)

    if @keyword.save
      respond_to do |format|
        format.turbo_stream do
          @keywords = Current.user.keywords.order(created_at: :asc)
          render turbo_stream: turbo_stream.replace(
            "keywords_list",
            partial: "keywords/chips_list",
            locals: { keywords: @keywords }
          )
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
        @keywords = Current.user.keywords.order(created_at: :asc)
        render turbo_stream: turbo_stream.replace(
          "keywords_list",
          partial: "keywords/chips_list",
          locals: { keywords: @keywords }
        )
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

  def add_default_keywords
    %w[변론 검찰조사 재판].each do |keyword_name|
      Current.user.keywords.find_or_create_by(keyword: keyword_name) do |kw|
        kw.is_active = true
      end
    end
  end

  def keyword_params
    params.require(:keyword).permit(:keyword, :name)
  end
end
