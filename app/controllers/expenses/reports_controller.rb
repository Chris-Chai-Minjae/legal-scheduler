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

      report = Current.session.user.expense_reports.build(
        title: params[:title].presence || "지출결의서 #{Date.current.strftime('%Y-%m-%d')}",
        card_statement_id: params[:card_statement_id],
        status: :pending
      )

      if report.save
        expense_ids.each_with_index do |expense_id, idx|
          report.expense_report_items.create!(
            expense_id: expense_id,
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
