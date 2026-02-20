module Expenses
  class CardStatementsController < ApplicationController
    before_action :require_authentication
    layout "dashboard"

    def index
      @card_statements = Current.session.user.card_statements.order(created_at: :desc)
    end

    def show
      @card_statement = Current.session.user.card_statements.find(params[:id])
      @expenses = @card_statement.expenses.by_date

      if params[:card_name].present?
        @expenses = @expenses.by_card(params[:card_name])
      end

      if params[:category].present?
        @expenses = @expenses.by_category(params[:category])
      end
    end

    def create
      unless params[:file].present?
        redirect_to expenses_card_statements_path, alert: "Excel 파일을 선택해주세요."
        return
      end

      file = params[:file]
      ext = File.extname(file.original_filename).downcase

      unless %w[.xlsx .xls].include?(ext)
        redirect_to expenses_card_statements_path, alert: "Excel 파일(.xlsx, .xls)만 업로드 가능합니다."
        return
      end

      statement = Current.session.user.card_statements.build(
        filename: file.original_filename,
        status: :pending
      )
      statement.file.attach(file)

      if statement.save
        CardStatementParseJob.perform_later(statement.id)
        redirect_to expenses_card_statement_path(statement), notice: "파일이 업로드되었습니다. 파싱이 시작됩니다."
      else
        redirect_to expenses_card_statements_path, alert: "업로드에 실패했습니다."
      end
    end

    def destroy
      statement = Current.session.user.card_statements.find(params[:id])
      statement.destroy
      redirect_to expenses_card_statements_path, notice: "카드 내역이 삭제되었습니다."
    end
  end
end
