module Expenses
  class ReportsController < ApplicationController
    include ActionController::Live

    before_action :require_authentication
    layout "dashboard"

    def index
      @reports = Current.session.user.expense_reports.order(created_at: :desc)
    end

    def show
      @report = Current.session.user.expense_reports.find(params[:id])
      @expenses = @report.expenses.order("expense_report_items.position")
    end

    def new
      @expenses = Current.session.user.expenses.classified.by_date
      @report = ExpenseReport.new

      if params[:card_statement_id].present?
        @expenses = @expenses.where(card_statement_id: params[:card_statement_id])
      end
    end

    def create
      expense_ids = params[:expense_ids] || []

      if expense_ids.empty?
        redirect_to new_expenses_report_path, alert: "경비를 하나 이상 선택해주세요."
        return
      end

      # P1 FIX: expense_ids 소유권 검증 - 현재 사용자의 경비만 허용
      verified_expenses = Current.session.user.expenses.where(id: expense_ids)
      if verified_expenses.count != expense_ids.uniq.size
        redirect_to new_expenses_report_path, alert: "선택한 경비 중 접근할 수 없는 항목이 포함되어 있습니다."
        return
      end

      # P2 FIX: card_statement_id 소유권 검증
      verified_card_statement_id = nil
      if params[:card_statement_id].present?
        card_statement = Current.session.user.card_statements.find_by(id: params[:card_statement_id])
        verified_card_statement_id = card_statement&.id
      end

      report = Current.session.user.expense_reports.build(
        title: params[:title].presence || "지출결의서 #{Date.current.strftime('%Y-%m-%d')}",
        card_statement_id: verified_card_statement_id,
        status: :pending
      )

      if report.save
        # 사용자가 선택한 순서(expense_ids) 보존
        ordered_expenses = expense_ids.map { |id| verified_expenses.find { |e| e.id == id.to_i } }.compact
        ordered_expenses.each_with_index do |expense, idx|
          report.expense_report_items.create!(
            expense_id: expense.id,
            position: idx + 1
          )
        end

        report.recalculate!
        ExpenseReportGenerateJob.perform_later(report.id)
        redirect_to expenses_report_path(report), notice: "지출결의서 생성이 시작되었습니다."
      else
        redirect_to new_expenses_report_path, alert: "보고서 생성에 실패했습니다."
      end
    end

    def download
      report = Current.session.user.expense_reports.find(params[:id])

      unless report.completed? && report.output_file.attached?
        redirect_to expenses_report_path(report), alert: "파일이 아직 준비되지 않았습니다."
        return
      end

      # Stream the file
      response.headers["Content-Type"] = "application/hwp+zip"
      response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
        disposition: "attachment",
        filename: report.output_file.filename.to_s
      )

      report.output_file.download do |chunk|
        response.stream.write(chunk)
      end
    rescue IOError, Errno::EPIPE => e
      Rails.logger.warn("[ReportsController] Stream interrupted: #{e.message}")
    ensure
      response.stream.close rescue nil
    end
  end
end
