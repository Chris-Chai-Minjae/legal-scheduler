require "csv"

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
      uploaded_files = Array(params[:files]).reject(&:blank?)

      if uploaded_files.empty?
        redirect_to expenses_card_statements_path, alert: "Excel 파일을 선택해주세요."
        return
      end

      # Validate all files before processing
      uploaded_files.each do |file|
        ext = File.extname(file.original_filename).downcase
        unless %w[.xlsx .xls].include?(ext)
          redirect_to expenses_card_statements_path, alert: "#{file.original_filename}: Excel 파일(.xlsx, .xls)만 업로드 가능합니다."
          return
        end

        if file.size > 10.megabytes
          redirect_to expenses_card_statements_path, alert: "#{file.original_filename}: 파일 크기는 10MB 이하만 가능합니다."
          return
        end
      end

      # 다중 파일을 하나의 통합 명세로 생성
      filenames = uploaded_files.map(&:original_filename)
      combined_name = if filenames.size == 1
        filenames.first
      else
        "#{filenames.first} 외 #{filenames.size - 1}건"
      end

      statement = Current.session.user.card_statements.new(
        filename: combined_name,
        status: :pending
      )
      statement.files.attach(uploaded_files)

      if statement.save
        CardStatementParseJob.perform_later(statement.id)
        redirect_to expenses_card_statement_path(statement), notice: "#{uploaded_files.size}개 파일이 업로드되었습니다. 통합 파싱이 시작됩니다."
      else
        redirect_to expenses_card_statements_path, alert: "업로드에 실패했습니다: #{statement.errors.full_messages.join(', ')}"
      end
    end

    def download_excel
      statement = Current.session.user.card_statements.find(params[:id])

      unless statement.completed?
        redirect_to expenses_card_statement_path(statement), alert: "분류가 완료된 후 다운로드할 수 있습니다."
        return
      end

      expenses = statement.expenses.classified.by_date

      csv_data = generate_csv(expenses)
      filename = "경비분류결과_#{Date.current.strftime('%Y-%m-%d')}.csv"

      send_data csv_data, filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment"
    end

    def destroy
      statement = Current.session.user.card_statements.find(params[:id])
      statement.destroy
      redirect_to expenses_card_statements_path, notice: "카드 내역이 삭제되었습니다."
    end

    private

    def generate_csv(expenses)
      bom = "\xEF\xBB\xBF".force_encoding("UTF-8")
      headers = %w[순번 거래일 가맹점 금액 카드사 계정과목 적요 비고]

      csv_string = CSV.generate do |csv|
        csv << headers
        expenses.each_with_index do |expense, idx|
          amount_str = if expense.try(:foreign_currency).present? && expense.try(:foreign_amount).present?
            "#{expense.foreign_currency} #{expense.foreign_amount} (#{ActiveSupport::NumberHelper.number_to_delimited(expense.amount)}원)"
          else
            "#{ActiveSupport::NumberHelper.number_to_delimited(expense.amount)}원"
          end

          csv << [
            idx + 1,
            expense.transaction_date&.strftime("%Y-%m-%d"),
            expense.merchant,
            amount_str,
            expense.card_name,
            expense.category,
            expense.description,
            expense.memo
          ]
        end
      end

      bom + csv_string
    end
  end
end
